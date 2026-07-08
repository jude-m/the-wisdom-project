import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/api_error_type.dart';
import '../../../domain/entities/research/chat_message.dart';
import '../../../domain/entities/research/citation.dart';
import '../../providers/research_chat_state.dart';
import '../../providers/research_provider.dart';
import 'citation_source_sheet.dart';
import 'research_error_messages.dart';

/// Minimal chat dialog for the AI Q&A feature.
///
/// Deliberately bare-bones (per "make it work first"): a scrolling transcript,
/// a text field, and a send button. No streaming, no threads. Citations render
/// as a tappable "Sources" list → [CitationSourceSheet] → open in reader.
class ResearchChatDialog extends ConsumerStatefulWidget {
  const ResearchChatDialog({super.key});

  /// Opens the dialog as a modal.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ResearchChatDialog(),
    );
  }

  @override
  ConsumerState<ResearchChatDialog> createState() => _ResearchChatDialogState();
}

class _ResearchChatDialogState extends ConsumerState<ResearchChatDialog> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(researchChatProvider.notifier).send(text);
    _controller.clear();
    // Scroll to the newest message after the frame lays it out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(researchChatProvider);
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    // When the model can't answer, retrying the same text won't help — restore
    // the user's question to the input so they can edit and rephrase it (plan
    // §4.4). Only fill an empty field, so we never clobber what they're typing.
    ref.listen<ResearchChatState>(researchChatProvider, (prev, next) {
      final becameCannotAnswer = next.errorType == ApiErrorType.cannotAnswer &&
          prev?.errorType != ApiErrorType.cannotAnswer;
      if (becameCannotAnswer &&
          _controller.text.isEmpty &&
          next.messages.isNotEmpty &&
          next.messages.last.isUser) {
        _controller.text = next.messages.last.content;
      }
    });

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.researchTitle,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  if (state.messages.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          ref.read(researchChatProvider.notifier).clear(),
                      child: Text(l10n.researchNewChat),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── Transcript ──────────────────────────────────────────
            Expanded(
              child: state.messages.isEmpty && !state.isLoading
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount:
                          state.messages.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.messages.length) {
                          return const _ThinkingRow();
                        }
                        return _MessageBubble(message: state.messages[index]);
                      },
                    ),
            ),

            // ── Error (if any) ──────────────────────────────────────
            // Message is chosen from the error KIND (offline vs quota vs timeout
            // vs …), and a Retry button appears only for retriable kinds.
            if (state.errorType != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        researchErrorMessage(l10n, state.errorType!),
                        style: TextStyle(color: colors.error, fontSize: 12),
                      ),
                    ),
                    if (canRetryType(state.errorType!))
                      TextButton(
                        onPressed: state.isLoading
                            ? null
                            : () => ref.read(researchChatProvider.notifier).retry(),
                        child: Text(l10n.researchRetry),
                      ),
                  ],
                ),
              ),

            const Divider(height: 1),

            // ── Input row ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: l10n.researchInputHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Disabled while a request is in flight — the cost guardrail.
                  IconButton.filled(
                    onPressed: state.isLoading ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: l10n.researchSend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown before the first question.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppLocalizations.of(context).researchEmptyState,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// The "thinking…" row shown while waiting for an answer.
class _ThinkingRow extends StatelessWidget {
  const _ThinkingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(AppLocalizations.of(context).researchThinking),
        ],
      ),
    );
  }
}

/// One tappable citation row: bold ref + title, snippet preview underneath.
/// Tapping opens [CitationSourceSheet]; if the user chooses "Open in reader"
/// there, the chat dialog is dismissed so the new reader tab is visible.
class _CitationRow extends StatelessWidget {
  const _CitationRow({required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () async {
        final openedInReader =
            await CitationSourceSheet.show(context, citation);
        if (openedInReader == true && context.mounted) {
          Navigator.of(context).pop(); // close the chat dialog → show reader
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 8, left: 2, right: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Heading line: bold ref + sutta title, e.g.
                  // "SN 15.6  Chapter One A Mustard Seed".
                  // Text.rich (not RichText) so system text scaling applies.
                  Text.rich(
                    TextSpan(
                      style: textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      children: [
                        TextSpan(text: citation.ref),
                        if (citation.title != null)
                          TextSpan(text: '  ${citation.title}'),
                      ],
                    ),
                  ),
                  // Snippet on its own line, in the muted body colour.
                  if (citation.snippet != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        citation.snippet!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// One chat bubble — user (right) or assistant (left, with sources).
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser
              ? colors.primaryContainer
              : colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(message.content),

            // Citations under the answer. Each row opens the cited-source
            // bottom sheet (snippet + "Open in reader" when the uid resolves
            // — see the resolver plan, Part D).
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).researchSources,
                style: textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              for (final citation in message.citations)
                _CitationRow(citation: citation),
            ],
          ],
        ),
      ),
    );
  }
}
