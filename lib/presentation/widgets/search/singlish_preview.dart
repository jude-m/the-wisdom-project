import 'package:flutter/material.dart';

/// "[සති]": the Sinhala that typed Singlish converts to, shown beside the
/// query. Takes at most 45% of [fieldWidth], so the typed text always stays
/// visible, and ends in an ellipsis when cut.
class SinglishPreview extends StatelessWidget {
  const SinglishPreview(this.text, {super.key, required this.fieldWidth});

  /// Display text from `singlishPreviewProvider`.
  final String text;

  /// Width of the search field the preview sits in.
  final double fieldWidth;

  static const double _maxWidthFraction = 0.45;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: fieldWidth * _maxWidthFraction),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
        ),
      ),
    );
  }
}
