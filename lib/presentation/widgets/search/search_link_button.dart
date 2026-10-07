import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// Text button with a small trailing icon: "See all →" and "View N more ⌄"
/// in the results list. 40px tall, so it is easy to tap.
class SearchLinkButton extends StatelessWidget {
  /// Space before the label. Callers subtract it to line the label up with
  /// the text above.
  static const double padding = 8;

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const SearchLinkButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      iconAlignment: IconAlignment.end,
      label: Text(label),
      style: TextButton.styleFrom(
        textStyle: context.typography.linkLabel,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: padding),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
