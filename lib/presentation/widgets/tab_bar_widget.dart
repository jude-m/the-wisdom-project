import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_typography.dart';
import '../providers/tab_lifecycle_provider.dart';
import '../providers/tab_provider.dart';

class TabBarWidget extends ConsumerStatefulWidget {
  const TabBarWidget({super.key});

  @override
  ConsumerState<TabBarWidget> createState() => _TabBarWidgetState();
}

class _TabBarWidgetState extends ConsumerState<TabBarWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _showLeftChevron = false;
  bool _showRightChevron = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateChevronVisibility);
    // Check initial state after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChevronVisibility();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateChevronVisibility);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateChevronVisibility() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final showLeft = position.pixels > 0;
    final showRight = position.pixels < position.maxScrollExtent;

    if (showLeft != _showLeftChevron || showRight != _showRightChevron) {
      setState(() {
        _showLeftChevron = showLeft;
        _showRightChevron = showRight;
      });
    }
  }

  void _scrollLeft() {
    final newOffset = (_scrollController.offset - 150).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    final newOffset = (_scrollController.offset + 150).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ref.watch(tabsProvider);
    final activeTabIndex = ref.watch(activeTabIndexProvider);

    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Schedule a check after build to update chevron visibility
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateChevronVisibility();
    });

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Left scroll chevron
          _ScrollChevron(
            icon: Icons.chevron_left,
            visible: _showLeftChevron,
            onTap: _scrollLeft,
          ),

          // Tab list
          Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
                scrollbars: false, // Hide scrollbar, we have chevrons
              ),
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final isActive = index == activeTabIndex;

                  return _TabItem(
                    tab: tab,
                    isActive: isActive,
                    onTap: () => ref.read(switchTabProvider)(index),
                    onClose: () => ref.read(closeTabProvider)(index),
                  );
                },
              ),
            ),
          ),

          // Right scroll chevron
          _ScrollChevron(
            icon: Icons.chevron_right,
            visible: _showRightChevron,
            onTap: _scrollRight,
          ),
        ],
      ),
    );
  }
}

class _ScrollChevron extends StatelessWidget {
  final IconData icon;
  final bool visible;
  final VoidCallback onTap;

  const _ScrollChevron({
    required this.icon,
    required this.visible,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 150),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: visible ? 28 : 0,
        child: visible
            ? InkWell(
                onTap: onTap,
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: Border(
                      left: icon == Icons.chevron_right
                          ? BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            )
                          : BorderSide.none,
                      right: icon == Icons.chevron_left
                          ? BorderSide(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            )
                          : BorderSide.none,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final dynamic tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 120,
          maxWidth: 200,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : Theme.of(context).colorScheme.surfaceContainerLowest,
          border: Border(
            right: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
            bottom: isActive
                ? BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : BorderSide.none,
          ),
        ),
        child: Row(
          children: [
            // Tab icon
            Icon(
              tab.hasContent
                  ? Icons.description_outlined
                  : Icons.folder_outlined,
              size: 16,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),

            // Tab label
            Expanded(
              child: Tooltip(
                message: tab.fullName,
                child: Text(
                  tab.label,
                  style: isActive
                      ? context.typography.tabLabelActive
                      : context.typography.tabLabelInactive,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Close button
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
