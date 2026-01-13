import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/responsive_utils.dart';
import '../widgets/tree_navigator_widget.dart';
import '../widgets/multi_pane_reader_widget.dart';
import '../widgets/tab_bar_widget.dart';
import '../widgets/settings_menu_button.dart';
import '../widgets/search/search_bar.dart' as app;
import '../widgets/search/search_results_panel.dart';
import '../widgets/resizable_divider.dart';
import '../providers/navigator_visibility_provider.dart';
import '../providers/tab_provider.dart';
import '../providers/search_provider.dart';
import '../providers/pane_width_provider.dart';
import '../../core/constants/constants.dart';
import '../../domain/entities/search/search_result.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  // FocusNode for keyboard shortcuts - must be disposed to prevent memory leaks
  final _keyboardFocusNode = FocusNode();

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _handleSearchResultTap(SearchResult result) {
    // Use centralized provider for consistent tab creation and navigation
    ref.read(openTabFromSearchResultProvider)(result);

    // Save to recent searches and dismiss panel
    ref.read(searchStateProvider.notifier).saveRecentSearchAndDismiss();

    // Close navigator on mobile so user can see the content
    if (ResponsiveUtils.isMobile(context)) {
      ref.read(navigatorVisibleProvider.notifier).state = false;
    }
  }

  void _closeSearchPanel() {
    ref.read(searchStateProvider.notifier).dismissResultsPanel();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final screenWidth = ResponsiveUtils.screenWidth(context);
    final isMobile = ResponsiveUtils.isMobile(context);
    final isTabletOrDesktop = ResponsiveUtils.isTabletOrDesktop(context);
    final navigatorVisible = ref.watch(navigatorVisibleProvider);

    // Watch search state to show/hide search panel
    final searchState = ref.watch(searchStateProvider);

    // Watch pane widths from providers
    final navigatorWidth = ref.watch(navigatorWidthProvider);
    final searchPanelWidth = ref.watch(searchPanelWidthProvider);

    // Calculate effective navigator width (0 if hidden or on mobile)
    final effectiveNavWidth =
        (isTabletOrDesktop && navigatorVisible) ? navigatorWidth : 0.0;

    // Calculate dynamic max for search panel (ensure 400px reader content)
    final searchPanelMaxWidth = (screenWidth - effectiveNavWidth - 400.0)
        .clamp(PaneWidthConstants.searchMin, PaneWidthConstants.searchMaxAbsolute);

    // Clamp search panel width to dynamic max
    final effectiveSearchWidth = searchPanelWidth.clamp(
      PaneWidthConstants.searchMin,
      searchPanelMaxWidth,
    );

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        // Close search panel on Escape key
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            searchState.isResultsPanelVisible) {
          _closeSearchPanel();
        }
      },
      child: Scaffold(
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
          actions: const [
            // Search bar (fixed width with overlay dropdown)
            app.SearchBar(),

            // Settings menu
            SettingsMenuButton(),
          ],
        ),
        body: Stack(
          children: [
            // Main reader layout - Navigator full height, Divider below tab bar
            Row(
              children: [
                // Navigator (full height, left side)
                if (isTabletOrDesktop && navigatorVisible)
                  SizedBox(
                    width: navigatorWidth,
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

                // Reader area with tabs and divider
                Expanded(
                  child: Column(
                    children: [
                      // Tab bar (full width of this column)
                      const TabBarWidget(),
                      // Content area with divider + reader
                      Expanded(
                        child: Row(
                          children: [
                            // Resizable divider (only in content area, below tab bar)
                            if (isTabletOrDesktop && navigatorVisible)
                              ResizableDivider(
                                isEnabled: isTabletOrDesktop,
                                onDragUpdate: (delta) {
                                  final newWidth = navigatorWidth + delta;
                                  ref
                                      .read(navigatorWidthProvider.notifier)
                                      .state = newWidth.clamp(
                                    PaneWidthConstants.navigatorMin,
                                    PaneWidthConstants.navigatorMax,
                                  );
                                },
                              ),
                            // Reader content
                            const Expanded(child: MultiPaneReaderWidget()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Mobile: Full-screen navigator overlay (tablet/desktop use sidebar)
            if (isMobile && navigatorVisible)
              Positioned.fill(
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: const TreeNavigatorWidget(),
                ),
              ),

            // Search panel overlay (desktop: side panel, mobile: full-screen)
            if (searchState.isResultsPanelVisible) ...[
              // Dim barrier
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeSearchPanel,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(color: Colors.black54),
                  ),
                ),
              ),

              // Search results panel
              if (isMobile)
                // Mobile: Full-screen overlay with back button handling
                Positioned.fill(
                  child: PopScope(
                    canPop: false,
                    onPopInvokedWithResult: (didPop, result) {
                      if (!didPop) {
                        _closeSearchPanel();
                      }
                    },
                    child: SearchResultsPanel(
                      onClose: _closeSearchPanel,
                      onResultTap: _handleSearchResultTap,
                    ),
                  ),
                )
              else
                // Desktop/Tablet: Side panel sliding in from right
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: effectiveSearchWidth + PaneWidthConstants.dividerWidth,
                  child: Row(
                    children: [
                      // Resizable divider on left edge of search panel
                      ResizableDivider(
                        isEnabled: isTabletOrDesktop,
                        showPillBorder: true, // More visible on dark background
                        onDragUpdate: (delta) {
                          // Negative delta (drag left) = wider panel
                          final newWidth = searchPanelWidth - delta;
                          ref.read(searchPanelWidthProvider.notifier).state =
                              newWidth.clamp(
                            PaneWidthConstants.searchMin,
                            searchPanelMaxWidth,
                          );
                        },
                      ),
                      Expanded(
                        child: SearchResultsPanel(
                          onClose: _closeSearchPanel,
                          onResultTap: _handleSearchResultTap,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
