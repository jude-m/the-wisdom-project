import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wisdom_shared/wisdom_shared.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/utils/url_launcher_utils.dart';
import '../../providers/deep_link_provider.dart';
import '../../providers/tab_provider.dart';

// The reader's outward buttons (deep-linking doc, Section B): Share, whose menu
// holds Copy link and is where sharing grows, and on the web Open as web page.

enum _ShareAction { copyLink }

/// Space between the button and the menu below it.
const double _menuGap = 8;

/// [context]'s box in global coordinates: the anchor for [showShareMenu].
Rect globalRectOf(BuildContext context) {
  final box = context.findRenderObject()! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Opens the Share menu under [anchor] for the active tab.
///
/// [anchor] is the tapped button's [globalRectOf], taken by the caller: the
/// FAB's item is gone once the FAB closes. That is also why the menu is
/// [showMenu], which needs only a position, and not a `MenuAnchor`.
Future<void> showShareMenu(
  BuildContext context,
  WidgetRef ref,
  Rect anchor,
) async {
  final l10n = AppLocalizations.of(context);
  final action = await showMenu<_ShareAction>(
    context: context,
    position: _below(context, anchor),
    items: [
      _menuItem(_ShareAction.copyLink, Icons.content_copy, l10n.copyLink),
    ],
  );
  if (action == null || !context.mounted) return;

  final link = _activeTabLink(ref);
  if (link == null) return;
  switch (action) {
    case _ShareAction.copyLink:
      await _copyLink(context, ref, link);
  }
}

/// Opens the active tab's text on the static site, in a new tab. Web only.
/// A short sutta opens as `<chapter>#<sutta>`, the page the site serves.
Future<void> openAsWebPage(BuildContext context, WidgetRef ref) async {
  final link = _activeTabLink(ref);
  if (link == null) return;
  final url = await ref.read(tipitakaLinkUrlBuilderProvider)(link);
  if (!context.mounted) return;
  await UrlLauncherUtils.launchInAppBrowser(context, url.toString());
}

TipitakaLink? _activeTabLink(WidgetRef ref) {
  final nodeKey = ref.read(activeNodeKeyProvider);
  return nodeKey == null ? null : TipitakaLink(nodeKey: nodeKey);
}

Future<void> _copyLink(
  BuildContext context,
  WidgetRef ref,
  TipitakaLink link,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final message = AppLocalizations.of(context).linkCopied;
  await ref.read(copyTipitakaLinkProvider)(link);
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/// Right-aligned under [anchor], as [PopupMenuButton] places a menu below its
/// button.
RelativeRect _below(BuildContext context, Rect anchor) {
  final overlay =
      Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
  final topLeft = anchor.bottomLeft.translate(0, _menuGap);
  return RelativeRect.fromRect(
    Rect.fromPoints(
      overlay.globalToLocal(topLeft),
      overlay.globalToLocal(topLeft + Offset(anchor.width, 0)),
    ),
    Offset.zero & overlay.size,
  );
}

PopupMenuItem<_ShareAction> _menuItem(
  _ShareAction action,
  IconData icon,
  String label,
) {
  return PopupMenuItem<_ShareAction>(
    value: action,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}
