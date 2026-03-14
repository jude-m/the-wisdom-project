import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/l10n/app_localizations.dart';

/// Utility for launching URLs and extracting links from HTML content.
abstract final class UrlLauncherUtils {
  /// Allowed URL schemes for launching.
  static const _allowedSchemes = {'http', 'https'};

  /// Regex to extract the href attribute from an <a> tag.
  /// Handles both double-quoted and single-quoted href values.
  static final _hrefRegex =
      RegExp(r'''<a\s+href=["']([^"']*)["'][^>]*>''', caseSensitive: false);

  /// Launches [urlString] in an in-app browser view.
  ///
  /// Uses SFSafariViewController on iOS, Chrome Custom Tabs on Android,
  /// and falls back to the external browser on desktop platforms.
  ///
  /// Only http and https URLs are allowed. Shows a SnackBar with a
  /// localized error message if the URL cannot be launched.
  static Future<void> launchInAppBrowser(
    BuildContext context,
    String urlString,
  ) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null || !_allowedSchemes.contains(uri.scheme)) return;

    // Capture localized string before async gap
    final errorMessage = AppLocalizations.of(context).couldNotOpenLink;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  /// Extracts the first href URL from HTML containing <a> tags.
  ///
  /// Returns null if no <a> tag with an href is found.
  static String? extractFirstHref(String html) {
    final match = _hrefRegex.firstMatch(html);
    return match?.group(1);
  }
}
