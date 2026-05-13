import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n/app_localizations.dart';
import '../../core/version/version_check_service.dart';
import '../../core/version/web_reload.dart';
import '../providers/version_check_provider.dart';

// Header icon (20 px) + gap (10 px) — body content uses this as a
// start inset so notes line up under the title text.
const double _contentIndent = 30;

class UpdateAvailableBanner extends ConsumerWidget {
  const UpdateAvailableBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(versionCheckProvider);

    return SafeArea(
      child: Align(
        alignment: AlignmentDirectional.topEnd,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            // Key embeds the remote SHA so a second deploy arriving
            // while the banner is showing cross-fades instead of
            // blinking in place.
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              reverseDuration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: _slideAndFade,
              child: info == null
                  ? const SizedBox.shrink(key: ValueKey('empty'))
                  : _CardBody(
                      info: info,
                      onDismiss: () =>
                          ref.read(versionCheckProvider.notifier).dismiss(),
                      key: ValueKey('card-${info.remoteSha}'),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _slideAndFade(Widget child, Animation<double> animation) {
    final slide = Tween<Offset>(
      begin: const Offset(1.0, 0),
      end: Offset.zero,
    ).animate(animation);
    return SlideTransition(
      position: slide,
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

class _CardBody extends StatelessWidget {
  final UpdateInfo info;
  final VoidCallback onDismiss;

  const _CardBody({
    required this.info,
    required this.onDismiss,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Material(
      color: colors.tertiary,
      elevation: 6,
      // App-palette warm brown tints the drop-shadow with the same hue
      // as the rest of the chrome instead of a flat black bruise.
      shadowColor: colors.shadow.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update_alt,
                  color: colors.onTertiary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.updateBannerTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.updateBannerDismissTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    color: colors.onTertiary,
                    size: 18,
                  ),
                  onPressed: onDismiss,
                ),
              ],
            ),

            if (info.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _contentIndent,
                  end: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < info.notes.length; i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      Text(
                        '${i + 1}. ${info.notes[i]}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            // Row(mainAxisSize.max) is what gives us a full-width slot
            // to centre the button in — a bare Center gets shrink-
            // wrapped to the button's own width inside this Column.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.onTertiary,
                    foregroundColor: colors.tertiary,
                    elevation: 3,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                  ),
                  onPressed: reloadPage,
                  child: Text(l10n.updateBannerRefreshAction),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
