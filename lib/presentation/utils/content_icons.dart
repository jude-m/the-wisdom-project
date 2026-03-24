import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Returns the appropriate icon and tint color for a content type.
/// Parent nodes: book_4/book_5, Leaf nodes: article.
/// Colors: Sutta (onErrorContainer maroon), Commentary (onTertiaryContainer sage),
/// Treatise (secondary warm taupe).
/// isCommentary and isTreatise are mutually exclusive
({IconData icon, Color color}) contentIcon({
  required bool isCommentary,
  bool isTreatise = false,
  bool hasChildren = false,
  required ColorScheme colorScheme,
  bool isExpanded = false,
}) {
  final IconData icon;
  if (hasChildren) {
    icon = isExpanded ? Symbols.book_5_sharp : Symbols.book_4_sharp;
  } else {
    icon = Symbols.description_sharp;
  }

  final Color color;
  if (isCommentary) {
    color = colorScheme.onTertiaryContainer;
  } else if (isTreatise) {
    color = colorScheme.secondary;
  } else {
    color = colorScheme.onErrorContainer;
  }

  return (icon: icon, color: color);
}
