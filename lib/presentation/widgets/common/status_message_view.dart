import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';

/// Visual variant for [StatusMessageView].
///
/// Each variant maps to a default icon, icon colour and title style so
/// callers only need to provide the message — the chrome is fixed.
enum StatusVariant {
  /// In-flight async work. Renders a [CircularProgressIndicator]; title
  /// (if provided) is shown below the spinner in a subdued style.
  loading,

  /// Neutral hint or tip (e.g. "Type to search").
  info,

  /// Bad input from the user (e.g. "Enter a valid search query").
  invalid,

  /// Successful query that returned zero results.
  empty,

  /// Generic failure (parse error, unexpected exception).
  error,

  /// Server unreachable — network/connectivity issue.
  offline,
}

/// One unified, in-panel status/feedback widget.
///
/// Replaces the ad-hoc loading / empty / error / "no results" widgets that
/// were duplicated across the search panel, dictionary sheet, navigation
/// tree and reader. Use this anywhere a panel needs to fill its content
/// area with a centred status message.
///
/// Example:
/// ```dart
/// StatusMessageView(
///   variant: StatusVariant.offline,
///   title: 'Cannot reach the server',
///   description: 'Check your connection and try again.',
///   action: TextButton.icon(
///     icon: const Icon(Icons.refresh),
///     label: const Text('Retry'),
///     onPressed: onRetry,
///   ),
/// );
/// ```
class StatusMessageView extends StatelessWidget {
  /// Side length of the leading icon / image, in logical pixels. The [Icon]
  /// and the [imageSize] default both read this so a tweak to one can't
  /// silently desync from the other.
  static const double _leadingSize = 40;

  /// Side length of the loading spinner's bounding box, in logical pixels.
  static const double _spinnerSize = 32;

  /// Which preset to render. Drives the default icon and colours.
  final StatusVariant variant;

  /// Optional override for the variant's default icon. Use sparingly —
  /// the whole point of this widget is visual consistency.
  final IconData? iconOverride;

  /// Optional asset image used as the leading visual instead of an icon.
  /// Must be a flat "template" shape — it is tinted with the variant's icon
  /// colour. Takes precedence over [iconOverride] and is ignored when
  /// [variant] is [StatusVariant.loading]. Use sparingly, for the same
  /// visual-consistency reason as [iconOverride].
  final String? imageAsset;

  /// Side length of [imageAsset] in logical pixels. Defaults to the
  /// standard leading-visual size.
  final double imageSize;

  /// Headline message shown to the user. Required for every variant
  /// except [StatusVariant.loading], where it is optional.
  final String? title;

  /// Optional supporting line shown under the title in a smaller style.
  final String? description;

  /// Optional action widget (typically an [OutlinedButton] or
  /// [TextButton.icon] for "Retry").
  final Widget? action;

  /// Outer padding around the centred column. Defaults to
  /// `EdgeInsets.symmetric(horizontal: 32, vertical: 16)`.
  final EdgeInsets padding;

  const StatusMessageView({
    super.key,
    required this.variant,
    this.title,
    this.iconOverride,
    this.imageAsset,
    this.imageSize = _leadingSize,
    this.description,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
  }) : assert(
          variant == StatusVariant.loading || title != null,
          'A non-loading StatusMessageView must have a title.',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final typography = context.typography;

    // Leading visual: spinner for loading, asset image, or icon.
    final Widget leading;
    if (variant == StatusVariant.loading) {
      leading = const SizedBox(
        width: _spinnerSize,
        height: _spinnerSize,
        child: CircularProgressIndicator(strokeWidth: 3),
      );
    } else if (imageAsset != null) {
      // Decode the bitmap at display resolution rather than its intrinsic
      // size, so a large source PNG doesn't sit in the image cache full-size.
      final cacheExtent =
          (imageSize * MediaQuery.devicePixelRatioOf(context)).round();
      // srcIn paints the variant colour through the asset's alpha,
      // so the shape tints correctly in light & dark themes.
      leading = Image.asset(
        imageAsset!,
        width: imageSize,
        height: imageSize,
        cacheWidth: cacheExtent,
        cacheHeight: cacheExtent,
        color: _iconColor(variant, colorScheme),
        colorBlendMode: BlendMode.srcIn,
      );
    } else {
      leading = Icon(
        iconOverride ?? _defaultIcon(variant),
        size: _leadingSize,
        color: _iconColor(variant, colorScheme),
      );
    }

    // Title style depends on whether the message is "negative" (error/offline)
    // or "informational" (empty/info/invalid/loading). This keeps error states
    // visually distinct without making other states look alarming.
    final TextStyle titleStyle =
        (variant == StatusVariant.error || variant == StatusVariant.offline)
            ? typography.errorMessage
            : typography.emptyStateMessage;

    final TextStyle? descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            if (title != null) ...[
              const SizedBox(height: 12),
              Text(
                title!,
                style: titleStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description!,
                style: descriptionStyle,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  /// Default icon for each variant. Override via [iconOverride] only when
  /// a specific screen has a strong reason to deviate.
  static IconData _defaultIcon(StatusVariant variant) {
    switch (variant) {
      case StatusVariant.loading:
        // Unused — loading uses a spinner — but kept for completeness.
        return Icons.hourglass_empty;
      case StatusVariant.info:
        return Icons.info_outline;
      case StatusVariant.invalid:
        return Icons.edit_note;
      case StatusVariant.empty:
        return Icons.search_off;
      case StatusVariant.error:
        return Icons.error_outline;
      case StatusVariant.offline:
        return Icons.cloud_off;
    }
  }

  /// Icon colour per variant. Errors use the theme's error colour; other
  /// variants use the muted on-surface variant so they don't shout.
  static Color _iconColor(StatusVariant variant, ColorScheme colorScheme) {
    switch (variant) {
      case StatusVariant.error:
      case StatusVariant.offline:
        return colorScheme.error;
      case StatusVariant.loading:
      case StatusVariant.info:
      case StatusVariant.invalid:
      case StatusVariant.empty:
        return colorScheme.onSurfaceVariant;
    }
  }
}

/// Heuristic that decides whether an error came from a network/server
/// problem (→ [StatusVariant.offline]) or something else
/// (→ [StatusVariant.error]).
///
/// Used by panels that surface an [Object] error from an `AsyncValue` or
/// `Failure` and want to show the right preset.
///
/// We deliberately avoid `dart:io` here so this works on Flutter web,
/// where `SocketException` lives in the same package but the runtime
/// surface differs. We match by the exception's runtime type name and
/// by common substrings in its message.
StatusVariant statusVariantForError(Object error) {
  // Failure carries the original exception in `error`. Unwrap one level so
  // a wrapped SocketException is recognised as offline.
  final Object effective = _unwrapFailure(error);

  final typeName = effective.runtimeType.toString();
  final message = effective.toString().toLowerCase();

  const networkTypeMarkers = <String>[
    'SocketException',
    'TimeoutException',
    'HandshakeException',
    'HttpException',
    'ClientException',
  ];
  for (final marker in networkTypeMarkers) {
    if (typeName.contains(marker)) return StatusVariant.offline;
  }

  // Substrings must be specific enough not to swallow non-network errors.
  // - Bare 'timeout' is intentionally absent: TimeoutException is already
  //   matched above by type name; without that anchor 'timeout' false-fires
  //   on cache/animation/debounce errors.
  // - Web fetch errors are anchored on the browser's TypeError prefix so a
  //   message like "JSON load failed at line 3" stays a parse error.
  const networkMessageMarkers = <String>[
    'failed host lookup',
    'connection refused',
    'connection closed',
    'connection reset',
    'network is unreachable',
    'no address associated with hostname',
    'software caused connection abort',
    'xmlhttprequest error', // Flutter web fetch failure
    'typeerror: failed to fetch', // Chrome / Firefox fetch failure
    'typeerror: load failed', // Safari fetch failure
  ];
  for (final marker in networkMessageMarkers) {
    if (message.contains(marker)) return StatusVariant.offline;
  }

  return StatusVariant.error;
}

/// Best-effort unwrap of a `Failure`-shaped object to its underlying
/// exception. We match by duck typing (`.error` getter) so this widget
/// has no dependency on the domain layer.
///
/// One level only — we do NOT recurse. Nested wrappers (a Failure whose
/// `.error` is itself a Failure) are not a real pattern in this codebase
/// and recursing would risk infinite loops on cyclic graphs.
Object _unwrapFailure(Object failure) {
  try {
    final dynamic dyn = failure;
    final inner = dyn.error;
    if (inner is Object) return inner;
  } catch (_) {
    // Object had no `error` getter — fall through.
  }
  return failure;
}
