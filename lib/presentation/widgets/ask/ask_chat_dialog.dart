import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/ask/chat_message.dart';
import '../../providers/ask_provider.dart';

/// Minimal chat dialog for the AI Q&A feature.
///
/// Deliberately bare-bones (per "make it work first"): a scrolling transcript,
/// a text field, and a send button. No streaming, no threads, no tappable
/// citation links yet — citations render as a plain "Sources" list.
///
/// TODO(i18n): move the hard-coded English strings into ARB (app_en.arb /
/// app_si.arb) once the feature is past the stub stage.
class AskChatDialog extends ConsumerStatefulWidget {
  const AskChatDialog({super.key});

  /// Opens the dialog as a modal.
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AskChatDialog(),
    );
  }

  @override
  ConsumerState<AskChatDialog> createState() => _AskChatDialogState();
}

class _AskChatDialogState extends ConsumerState<AskChatDialog> {
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
    ref.read(askChatProvider.notifier).send(text);
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
    final state = ref.watch(askChatProvider);
    final colors = Theme.of(context).colorScheme;

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
                  const Expanded(
                    child: Text(
                      'Ask the Canon',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  if (state.messages.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          ref.read(askChatProvider.notifier).clear(),
                      child: const Text('New chat'),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
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
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    state.error!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
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
                      decoration: const InputDecoration(
                        hintText: 'Ask a question about the suttas…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Disabled while a request is in flight — the cost guardrail.
                  IconButton.filled(
                    onPressed: state.isLoading ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Send',
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
          'Ask anything about the Pali Canon.\n\n'
          '(This is a stub — answers are canned until the backend is connected.)',
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
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Thinking…'),
        ],
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

            // Citations as a plain "Sources" list — no tappable links yet
            // (deep-linking is a later phase; see the resolver plan, Part D).
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Sources',
                style: textTheme.labelSmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              for (final citation in message.citations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: RichText(
                    text: TextSpan(
                      style: textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: citation.ref,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (citation.snippet != null)
                          TextSpan(text: ' — ${citation.snippet}'),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
