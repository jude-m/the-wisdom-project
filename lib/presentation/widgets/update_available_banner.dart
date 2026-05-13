import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/l10n/app_localizations.dart';
import '../../core/version/version_check_service.dart';
import '../../core/version/web_reload.dart';
import '../providers/version_check_provider.dart';

/// Lines notes / button up under the title text. The icon is 20 px
/// wide and there's a 10 px gap after it, so the body content needs
/// a 30 px start inset to read as a single indented block.
const double _contentIndent = 30;

/// Notification card shown when a fresher build is live on the server
/// (see [VersionCheckNotifier]). Renders nothing when there's no update
/// — the parent can always include it unconditionally.
///
/// Designed as a self-contained overlay layer:
///   - The caller (`main.dart`) wraps it in `Positioned.fill` inside a
///     Stack, so this widget itself stays portable — it can also drop
///     into an OverlayEntry without modification.
///   - Anchors top-right; slides in from the right and fades on enter;
///     reverses on dismiss.
///   - Caps at 360 px wide so it stays a "card" on desktop while
///     fitting nicely on narrow widths.
///   - Background uses `colorScheme.tertiary` — the same mint green
///     the reader uses to highlight dictionary text — so the card
///     reads as an informational accent that fits the app's palette.
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
            // AnimatedSwitcher handles enter (null → info), exit
            // (info → null) AND swap (info_A → info_B) with the same
            // slide+fade. The key embeds the remote SHA so a second
            // deploy arriving while the banner is showing produces
            // a proper cross-fade instead of an in-place blink.
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
                      key: ValueKey('card-${info.remoteSha}'),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Slides the card in from the right (`+1.0` on the x-axis means one
  /// full child-width off-screen) while fading in. AnimatedSwitcher
  /// drives `animation` from 0→1 on enter and 1→0 on exit, so the same
  /// builder works for both directions.
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

class _CardBody extends ConsumerWidget {
  final UpdateInfo info;

  const _CardBody({required this.info, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    // Material gives us elevation + ripple-capable surface in one go.
    // `colorScheme.shadow` is the app-palette warm dark-brown, so the
    // drop-shadow tints with the same hue as the rest of the chrome
    // instead of a flat black bruise on the cream background.
    return Material(
      color: colors.tertiary,
      elevation: 6,
      shadowColor: colors.shadow.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: icon + title + dismiss ────────────────────
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colors.onTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Compact dismiss button. visualDensity.compact keeps
                // the header tight without sacrificing the 40 px touch
                // target Material insists on internally.
                IconButton(
                  tooltip: l10n.updateBannerDismissTooltip,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close,
                    color: colors.onTertiary,
                    size: 18,
                  ),
                  onPressed: () =>
                      ref.read(versionCheckProvider.notifier).dismiss(),
                ),
              ],
            ),

            // ── Notes: numbered list, indented under the title ────
            if (info.notes.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: _contentIndent,
                  end: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(info.notes.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${i + 1}. ${info.notes[i]}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onTertiary,
                          height: 1.35,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],

            // ── Refresh action ────────────────────────────────────
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: _contentIndent,
                end: 8,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  // Invert the colour role so the button pops against
                  // the mint-green card: dark-brown surface, mint label.
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.onTertiary,
                    foregroundColor: colors.tertiary,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: reloadPage,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: Text(l10n.updateBannerRefreshAction),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
