import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// The 40×40 square at the start of a result row: the edition (BJT) or the
/// dictionary (DPD). The constants keep the rows around it lined up.
class ResultBadge extends StatelessWidget {
  /// Side padding of a result row (its `ListTile` content padding).
  static const double rowPadding = 16;

  static const double _size = 40;

  /// Where the badge ends.
  static const double end = rowPadding + _size;

  /// Where a row's text starts: after the badge and `ListTile`'s 16px gap,
  /// or at the row padding when there is no badge.
  static double textStart(bool hasBadge) => hasBadge ? end + 16 : rowPadding;

  final String label;
  final Color backgroundColor;

  /// Null keeps the `badgeLabel` colour.
  final Color? labelColor;

  const ResultBadge({
    super.key,
    required this.label,
    required this.backgroundColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.typography.badgeLabel;
    return Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: labelColor == null ? style : style.copyWith(color: labelColor),
        ),
      ),
    );
  }
}
