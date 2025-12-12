import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/tree_navigator_widget.dart';
import '../widgets/multi_pane_reader_widget.dart';
import '../widgets/tab_bar_widget.dart';
import '../widgets/settings_menu_button.dart';
import '../widgets/search_bar.dart' as app;
import '../providers/navigator_visibility_provider.dart';
import '../providers/tab_provider.dart';
import '../../domain/entities/search/search_result.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  void _handleSearchResultTap(SearchResult result) {
    // Use centralized provider for consistent tab creation and navigation
    ref.read(openTabFromSearchResultProvider)(result);

    // Close navigator on mobile so user can see the content
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    if (!isDesktop) {
      ref.read(navigatorVisibleProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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
          app.SearchBar(onResultTap: _handleSearchResultTap),

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
