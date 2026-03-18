import 'package:flutter/material.dart';

/// A circular toggle button with active/inactive visual states.
/// Used for binary toggles like exact match and proximity in search/dictionary UIs.
class CircularToggleButton extends StatelessWidget {
  final bool isActive;
  final IconData icon;
  final double iconSize;
  final String? tooltip;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry margin;

  const CircularToggleButton({
    super.key,
    required this.isActive,
    required this.icon,
    required this.onPressed,
    this.iconSize = 20,
    this.tooltip,
    this.margin = const EdgeInsets.only(left: 4),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 30,
      width: 30,
      margin: margin,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Icon(
          icon,
          size: iconSize,
          color: isActive
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.primary,
        ),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
