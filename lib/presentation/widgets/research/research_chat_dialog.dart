import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/l10n/app_localizations.dart';
import '../../../domain/entities/api_error_type.dart';
import '../../../domain/entities/research/chat_message.dart';
import '../../providers/research_chat_state.dart';
import '../../providers/research_provider.dart';
import 'research_answer_view.dart';
import 'research_error_messages.dart';

/// Minimal chat dialog for the AI Q&A feature.
///
/// Deliberately bare-bones (per "make it work first"): a scrolling transcript,
/// a text field, and a send button. No streaming, no threads. Assistant answers
/// render via [ResearchAnswerView] with inline citation chips → peek → reader.
///
/// The `Dialog` shell here is intentionally thin: the feature will move to a
/// full-screen "Dhamma AI" tab, at which point only this wrapper is replaced —
/// [ResearchAnswerView] and the peek sheet carry over unchanged.
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

/// One chat bubble — user (right) or assistant (left, with inline citations).
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
        // User turns are plain text; assistant answers render with inline
        // citation chips. Choosing "Open in reader" in a chip's peek pops this
        // dialog so the reader tab is visible.
        child: isUser
            ? SelectableText(message.content)
            : ResearchAnswerView(
                answer: message.content,
                citations: message.citations,
                onCitationOpenedInReader: () {
                  // Guard the async gap: the peek could resolve after the dialog
                  // is already gone (matches the prior citation-row behaviour).
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
      ),
    );
  }
}
