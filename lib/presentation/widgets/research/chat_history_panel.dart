import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/research/chat_summary.dart';
import '../../providers/research_provider.dart';
import '../common/status_message_view.dart';

/// The saved-chats panel: "New chat" + the RECENT list.
///
/// One widget for both form factors — the desktop layout embeds it as a
/// persistent left panel, the mobile layout puts it inside a [Drawer]
/// (which passes [onChatSelected] to close itself after a tap).
class ChatHistoryPanel extends ConsumerWidget {
  const ChatHistoryPanel({super.key, this.onChatSelected});

  /// Called after a chat is opened / started / deleted-while-active, i.e.
  /// whenever the canvas changed and the panel is done. The mobile drawer
  /// closes itself here; desktop passes null.
  final VoidCallback? onChatSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final summaries = ref.watch(chatSummariesProvider);
    // Only the id matters here — don't rebuild the list on every transcript
    // change while an answer streams in.
    final activeId =
        ref.watch(researchChatProvider.select((s) => s.sessionId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── New chat ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: FilledButton.icon(
            onPressed: () {
              ref.read(researchChatProvider.notifier).newChat();
              onChatSelected?.call();
            },
            icon: const Icon(Icons.add),
            label: Text(l10n.researchNewChat),
          ),
        ),

        // ── "RECENT" header ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            l10n.researchRecent.toUpperCase(),
            // The shared section-header token, muted to sit back like a
            // sidebar label rather than a content heading.
            style: context.typography.sectionHeader
                .copyWith(color: colors.onSurfaceVariant),
          ),
        ),

        // ── Chat list ───────────────────────────────────────────
        Expanded(
          child: summaries.when(
            // A prefs read is effectively instant — no spinner needed.
            loading: () => const SizedBox.shrink(),
            error: (_, __) => _emptyHint(l10n),
            data: (chats) => chats.isEmpty
                ? _emptyHint(l10n)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    itemCount: chats.length,
                    itemBuilder: (context, index) => _ChatTile(
                      chat: chats[index],
                      selected: chats[index].id == activeId,
                      onChatSelected: onChatSelected,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  /// Empty (or unreadable) history — the app-wide status widget so the
  /// panel matches the search/dictionary empty states.
  Widget _emptyHint(AppLocalizations l10n) {
    return StatusMessageView(
      variant: StatusVariant.empty,
      iconOverride: Icons.chat_bubble_outline,
      title: l10n.researchNoRecentChats,
    );
  }
}

/// One row in the RECENT list: title + relative time, tap to open,
/// subtle trailing delete.
class _ChatTile extends ConsumerWidget {
  const _ChatTile({
    required this.chat,
    required this.selected,
    this.onChatSelected,
  });

  final ChatSummary chat;
  final bool selected;
  final VoidCallback? onChatSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      // Match the nav rail/bar's M3 selection language.
      selectedTileColor: colors.secondaryContainer,
      selectedColor: colors.onSecondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        _relativeTime(context, chat.updatedAt),
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline,
            size: 18, color: colors.onSurfaceVariant),
        tooltip: l10n.researchDeleteChat,
        onPressed: () {
          final wasActive = selected;
          ref.read(researchChatProvider.notifier).deleteChat(chat.id);
          // Deleting the open chat clears the canvas — treat it like a
          // selection so the mobile drawer closes onto the fresh state.
          if (wasActive) onChatSelected?.call();
        },
      ),
      onTap: () {
        ref.read(researchChatProvider.notifier).openChat(chat);
        onChatSelected?.call();
      },
    );
  }
}

/// "Just now" / "5 minutes ago" / "Yesterday" / "3 days ago", falling back
/// to a short date once it's a week old. Localised via ARB plurals.
String _relativeTime(BuildContext context, DateTime time) {
  final l10n = AppLocalizations.of(context);
  final now = DateTime.now();
  final elapsed = now.difference(time);

  if (elapsed.inMinutes < 1) return l10n.relativeTimeJustNow;
  if (elapsed.inMinutes < 60) return l10n.relativeTimeMinutesAgo(elapsed.inMinutes);
  if (elapsed.inHours < 24) return l10n.relativeTimeHoursAgo(elapsed.inHours);

  // Calendar-day distance for the day-granularity labels, so "yesterday
  // evening" reads as Yesterday even if fewer than 48 hours have passed.
  final today = DateTime(now.year, now.month, now.day);
  final thatDay = DateTime(time.year, time.month, time.day);
  final days = today.difference(thatDay).inDays;
  if (days <= 1) return l10n.relativeTimeYesterday;
  if (days < 7) return l10n.relativeTimeDaysAgo(days);
  return MaterialLocalizations.of(context).formatShortDate(time);
}
