import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/tree_navigator_widget.dart';
import '../widgets/multi_pane_reader_widget.dart';
import '../widgets/tab_bar_widget.dart';
import '../widgets/search_results_widget.dart';
import '../widgets/settings_menu_button.dart';
import '../widgets/search_bar.dart' as app;
import '../providers/search_provider.dart';
import '../providers/navigator_visibility_provider.dart';

class ReaderScreen extends ConsumerWidget {
  const ReaderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final navigatorVisible = ref.watch(navigatorVisibleProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
        leading: IconButton(
          icon: Icon(navigatorVisible ? Icons.menu_open : Icons.menu),
          tooltip: navigatorVisible ? 'Hide Navigator' : 'Show Navigator',
          onPressed: () {
            ref.read(navigatorVisibleProvider.notifier).state =
                !navigatorVisible;
          },
        ),
        actions: [
          // Search bar (fixed width with overlay dropdown)
          const app.SearchBar(),

          // Settings menu
          const SettingsMenuButton(),
        ],
      ),
      body: Stack(
        children: [
          // Main reader layout
          Row(
            children: [
              // Tree Navigator (left side) - desktop only when visible
              if (isDesktop && navigatorVisible)
                SizedBox(
                  width: 350,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: const TreeNavigatorWidget(),
                  ),
                ),

              // Reader area with tabs (right side)
              Expanded(
                child: Column(
                  children: const [
                    // Tab bar
                    TabBarWidget(),

                    // Multi-Pane Reader
                    Expanded(
                      child: MultiPaneReaderWidget(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Desktop: Search results overlay
          if (isDesktop) const _SearchResultsOverlay(),

          // Mobile: Full-screen navigator overlay
          if (!isDesktop && navigatorVisible)
            Positioned.fill(
              child: Material(
                color: Theme.of(context).colorScheme.surface,
                child: const TreeNavigatorWidget(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Desktop search results overlay
class _SearchResultsOverlay extends ConsumerWidget {
  const _SearchResultsOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasQuery = ref.watch(
      searchStateProvider.select((s) => s.queryText.trim().isNotEmpty),
    );

    if (!hasQuery) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 450,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            left: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: const SearchResultsWidget(),
      ),
    );
  }
}
