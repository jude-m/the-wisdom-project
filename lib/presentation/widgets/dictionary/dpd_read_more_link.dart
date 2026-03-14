import 'package:flutter/material.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/utils/url_launcher_utils.dart';

/// Tappable "Read more" link for DPD dictionary entries.
///
/// Extracts the first `<a>` href from [html] and renders a localized
/// "Read more" link that opens in an in-app browser.
/// Returns [SizedBox.shrink] if no link is found.
class DpdReadMoreLink extends StatelessWidget {
  /// The raw HTML content that may contain an `<a>` tag.
  final String html;

  /// Optional base text style. Defaults to [TextTheme.bodyMedium].
  /// Color and decoration are always overridden to show as a link.
  final TextStyle? baseStyle;

  /// Padding around the link. Defaults to 6px top.
  final EdgeInsetsGeometry padding;

  const DpdReadMoreLink({
    super.key,
    required this.html,
    this.baseStyle,
    this.padding = const EdgeInsets.only(top: 6),
  });

  @override
  Widget build(BuildContext context) {
    final href = UrlLauncherUtils.extractFirstHref(html);
    if (href == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final effectiveStyle = (baseStyle ?? theme.textTheme.bodyMedium)?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    return Padding(
      padding: padding,
      child: Semantics(
        link: true,
        child: InkWell(
          onTap: () => UrlLauncherUtils.launchInAppBrowser(context, href),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(l10n.readMore, style: effectiveStyle),
          ),
        ),
      ),
    );
  }
}
