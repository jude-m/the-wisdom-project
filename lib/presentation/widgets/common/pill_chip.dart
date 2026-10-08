import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// Filter chip: 32px pill, filled when [selected]. A real button, so it has
/// hover, focus, ripple, keyboard activation and a 40px+ tap area.
class PillChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool _refine;

  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  }) : _refine = false;

  /// The "Refine" chip: tune icon and its own colours, as it opens a dialog
  /// rather than filtering. [selected] means filters from the dialog are on.
  const PillChip.refine({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  }) : _refine = true;

  /// The chip's look, shared with other buttons in a chip row ("Starts
  /// with ▾" uses it with a rounded-rectangle [shape]).
  static ButtonStyle styleOf(
    BuildContext context, {
    required bool selected,
    bool refine = false,
    OutlinedBorder shape = const StadiumBorder(),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 14),
  }) {
    final colors = Theme.of(context).colorScheme;
    final typography = context.typography;
    final (background, foreground, border) = switch ((refine, selected)) {
      (false, false) => (
          colors.surfaceContainerLow,
          colors.onSurfaceVariant,
          colors.outline,
        ),
      (false, true) => (colors.secondary, colors.onSecondary, colors.secondary),
      (true, false) => (
          colors.surfaceContainerLowest,
          colors.onSurfaceVariant,
          colors.outline,
        ),
      (true, true) => (
          colors.primaryContainer,
          colors.onPrimaryContainer,
          colors.primary,
        ),
    };
    return TextButton.styleFrom(
      backgroundColor: background,
      // Also colours the text and icon, over the text style's own colour.
      foregroundColor: foreground,
      textStyle: selected ? typography.chipLabelSelected : typography.chipLabel,
      shape: shape,
      side: BorderSide(color: border),
      padding: padding,
      minimumSize: const Size(48, 32),
      visualDensity: VisualDensity.standard,
      // The pill stays 32px; the tap area grows to 48px around it.
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(label, maxLines: 1, softWrap: false);

    return TextButton(
      onPressed: onPressed,
      style: styleOf(
        context,
        selected: selected,
        refine: _refine,
        padding: _refine
            ? const EdgeInsetsDirectional.only(start: 10, end: 12)
            : const EdgeInsets.symmetric(horizontal: 14),
      ),
      // Inside the button, so it lands on the button's own semantics node.
      child: Semantics(
        selected: selected,
        child: _refine
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 16),
                  const SizedBox(width: 6),
                  text,
                ],
              )
            : text,
      ),
    );
  }
}
