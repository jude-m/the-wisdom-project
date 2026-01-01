import 'package:flutter/material.dart';

/// Vertical divider that can be dragged to resize adjacent panes.
///
/// Features:
/// - Pill-shaped handle indicator (centered)
/// - Hover state: pill becomes fully visible, light background
/// - Drag state: primary colored background and pill
/// - Desktop/Web: Shows resize cursor on hover
/// - Tablet: Touch-friendly 8px hit area
class ResizableDivider extends StatefulWidget {
  /// Called during drag with the horizontal delta in pixels.
  /// Positive values = dragging right, negative = dragging left.
  final ValueChanged<double> onDragUpdate;

  /// Called when drag ends (optional, for persistence if added later)
  final VoidCallback? onDragEnd;

  /// Whether resizing is enabled. Set to false on mobile.
  final bool isEnabled;

  /// Whether to show a subtle border around the pill for better visibility
  /// on dark backgrounds.
  final bool showPillBorder;

  const ResizableDivider({
    super.key,
    required this.onDragUpdate,
    this.onDragEnd,
    this.isEnabled = true,
    this.showPillBorder = false,
  });

  @override
  State<ResizableDivider> createState() => _ResizableDividerState();
}

class _ResizableDividerState extends State<ResizableDivider> {
  bool _isHovering = false;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Background only changes on drag (not hover) to avoid double color flash
    final backgroundColor = _isDragging
        ? colorScheme.primaryContainer
        : Colors.transparent;

    final pillColor = _isDragging ? colorScheme.primary : colorScheme.onSurface;

    final pillOpacity = (_isDragging || _isHovering) ? 1.0 : 0.4;

    // When disabled, just return an empty SizedBox (no visual divider on mobile)
    if (!widget.isEnabled) {
      return const SizedBox.shrink();
    }

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => setState(() => _isDragging = true),
        onHorizontalDragUpdate: (details) {
          widget.onDragUpdate(details.delta.dx);
        },
        onHorizontalDragEnd: (_) {
          setState(() => _isDragging = false);
          widget.onDragEnd?.call();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 8,
          color: backgroundColor,
          child: Center(
            // Pill-shaped handle indicator
            child: Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: pillColor.withValues(alpha: pillOpacity),
                // Subtle border for visibility on dark backgrounds
                border: widget.showPillBorder
                    ? Border.all(
                        color: colorScheme.surfaceContainerLowest,
                        width: 2,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
