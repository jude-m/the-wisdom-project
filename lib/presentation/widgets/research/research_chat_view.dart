import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../../core/localization/l10n/app_localizations.dart';
import '../../../core/theme/app_typography.dart';
import '../../../domain/entities/api_error_type.dart';
import '../../../domain/entities/research/chat_message.dart';
import '../../providers/research_chat_state.dart';
import '../../providers/research_mode_provider.dart';
import '../../providers/research_provider.dart';
import '../common/status_message_view.dart';
import 'research_answer_view.dart';
import 'research_error_messages.dart';
import 'research_mode_selector.dart';
import 'research_mode_ui.dart';

/// Maximum width of the conversation column — full-bleed text is hard to
/// read on desktop, so the transcript and the input row are centered like
/// the familiar chat apps. Shared with the citation peek sheet so it rises
/// aligned with the answers (PaneWidthConstants.researchContentMaxWidth).
const _kContentMaxWidth = PaneWidthConstants.researchContentMaxWidth;

/// The conversation itself: transcript, error row, turn-limit banner and
/// input. The Research section wraps this in its responsive shell (history
/// panel on desktop, drawer on mobile).
///
/// Optimistic sends, a mode-aware busy row while in flight, typed error messages
/// with Retry, and restoring an unanswerable question into the input for
/// rephrasing. Assistant answers render via [ResearchAnswerView] with inline
/// citation chips → peek → reader (the deep-link provider switches the app
/// to the Reader section itself).
class ResearchChatView extends ConsumerStatefulWidget {
  const ResearchChatView({super.key});

  @override
  ConsumerState<ResearchChatView> createState() => _ResearchChatViewState();
}

class _ResearchChatViewState extends ConsumerState<ResearchChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  // Stable identity for the input field. The composer swaps between a single
  // row (field beside the controls) and two rows (field above them) as the
  // text wraps — this GlobalKey lets Flutter relocate the SAME field element
  // across that switch, so focus and the keyboard aren't dropped mid-typing.
  final _fieldKey = GlobalKey();

  // Width to reserve for the trailing controls (mode chip + send button, plus
  // gaps) when deciding whether the question still fits on one line beside
  // them. Measured against this constant — not the live layout — so the
  // single↔two-row decision can't oscillate near the boundary.
  static const _kControlsReserve = 190.0;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    // The send button disables while a question is in flight, but Enter
    // (TextField.onSubmitted) still fires — mirror the notifier's gate here
    // so a dropped send doesn't clear what the user typed.
    final state = ref.read(researchChatProvider);
    if (state.isLoading || state.isAtTurnLimit) return;
    ref.read(researchChatProvider.notifier).send(text);
    _controller.clear();
  }

  /// Jump to the newest message after the frame lays it out.
  void _scrollToBottom() {
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

    ref.listen<ResearchChatState>(researchChatProvider, (prev, next) {
      // Follow the conversation: new turn appended (question or answer) or
      // another chat opened → show its end.
      if (prev?.messages.length != next.messages.length ||
          prev?.sessionId != next.sessionId) {
        _scrollToBottom();
      }

      // The input is shared across chats, but a draft belongs to the chat
      // it was typed in — clear it on a switch so a leftover (or a
      // cannotAnswer-restored question, below) can't be sent into another
      // chat and burn one of ITS turns.
      if (prev?.sessionId != next.sessionId) {
        _controller.clear();
      }

      // When the model can't answer, retrying the same text won't help —
      // restore the user's question to the input so they can edit and
      // rephrase it (plan §4.4). Only fill an empty field, so we never
      // clobber what they're typing.
      final becameCannotAnswer = next.errorType == ApiErrorType.cannotAnswer &&
          prev?.errorType != ApiErrorType.cannotAnswer;
      if (becameCannotAnswer &&
          _controller.text.isEmpty &&
          next.messages.isNotEmpty &&
          next.messages.last.isUser) {
        _controller.text = next.messages.last.content;
      }
    });

    // The banner replaces the input once the chat is out of turns (but not
    // while the final answer is still in flight). A failed final question
    // keeps its Retry in the error row above.
    final showLimitBanner = state.isAtTurnLimit && !state.isLoading;

    // A reopened chat whose last question never got an answer: errors are
    // transient state (openChat can't restore [errorType]), so the Retry
    // affordance is derived from the transcript's shape instead, with a
    // neutral message. Without this, a failed FINAL question would be stuck
    // for good behind the turn-limit banner.
    final hasUnansweredQuestion = state.errorType == null &&
        !state.isLoading &&
        state.messages.isNotEmpty &&
        state.messages.last.isUser;

    return Column(
      children: [
        // ── Transcript ──────────────────────────────────────────
        Expanded(
          child: state.messages.isEmpty && !state.isLoading
              ? StatusMessageView(
                  variant: StatusVariant.info,
                  // Matches the assistant avatar's glyph.
                  iconOverride: Icons.auto_awesome,
                  title: l10n.researchEmptyState,
                )
              : Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _kContentMaxWidth),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount:
                          state.messages.length + (state.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index >= state.messages.length) {
                          return const _BusyRow();
                        }
                        return _MessageTurn(message: state.messages[index]);
                      },
                    ),
                  ),
                ),
        ),

        // ── Error / unanswered-question row (if any) ────────────
        // Message is chosen from the error KIND (offline vs quota vs timeout
        // vs …), and a Retry button appears only for retriable kinds. With
        // no live error but an unanswered last question (reopened chat), the
        // neutral notice + Retry shows instead.
        if (state.errorType != null || hasUnansweredQuestion)
          _CenteredBottomRow(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    state.errorType != null
                        ? researchErrorMessage(
                            l10n,
                            state.errorType!,
                            // A retry re-sends under the currently selected
                            // tier, so the rate-limit hint keys on that mode.
                            mode: ref.watch(researchModeProvider),
                          )
                        : l10n.researchQuestionNotAnswered,
                    style: TextStyle(
                      // The neutral notice isn't an error — don't alarm.
                      color: state.errorType != null
                          ? colors.error
                          : colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (state.errorType == null || canRetryType(state.errorType!))
                  TextButton(
                    onPressed: state.isLoading
                        ? null
                        : () =>
                            ref.read(researchChatProvider.notifier).retry(),
                    child: Text(l10n.researchRetry),
                  ),
              ],
            ),
          ),

        // ── Input row / turn-limit banner ───────────────────────
        if (showLimitBanner)
          _CenteredBottomRow(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: colors.onSurfaceVariant),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.researchChatLimitReached,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.read(researchChatProvider.notifier).newChat(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.researchNewChat),
                  ),
                ],
              ),
            ),
          )
        else
          _CenteredBottomRow(
            // The composer is a single rounded pill — same rounding language as
            // the main search bar (BorderRadius.circular(20)) so the two inputs
            // feel like one family. The TextField, the Fast/Thinking selector and
            // the send button all live inside it on one row, with the two
            // controls grouped on the right (modern chat-composer layout).
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.outlineVariant),
              ),
              // Adaptive composer (Gemini-style): the controls sit inline on
              // the right while the question fits on one line, and drop to a
              // second row beneath it the moment the text wraps — so a growing
              // question never fights the chip and send button for the row.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inputStyle = Theme.of(context).textTheme.bodyLarge ??
                      DefaultTextStyle.of(context).style;

                  final textField = TextField(
                    key: _fieldKey,
                    controller: _controller,
                    style: inputStyle,
                    minLines: 1,
                    // Grows 1 → 5 lines, then holds and scrolls internally so a
                    // long paragraph stays reviewable without swallowing the
                    // transcript. maxLength matches the server's
                    // QUESTION_MAX_CHARS (contracts.ts) — a giant paste stops
                    // here instead of bouncing off a 400.
                    maxLines: 5,
                    maxLength: 4000,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l10n.researchInputHint,
                      // The container owns the shape now — no inner outline.
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      // Hide the live "n/4000" counter — typed questions never
                      // get near the cap; it only exists to stop pastes.
                      counterText: '',
                    ),
                  );

                  final controls = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fast/Thinking mode switch, relocated from the app bar
                      // into the composer.
                      const ResearchModeSelector(),
                      const SizedBox(width: 8),
                      // Disabled while a request is in flight — the cost guard.
                      IconButton.filled(
                        onPressed: state.isLoading ? null : _send,
                        icon: const Icon(Icons.send),
                        tooltip: l10n.researchSend,
                      ),
                    ],
                  );

                  // Re-evaluate the fit on every keystroke. Measure the text at
                  // the width it WOULD have beside the controls (single-row
                  // width); if it needs more than one line there, go two-row.
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) {
                      final singleRowTextWidth =
                          constraints.maxWidth - _kControlsReserve;
                      final painter = TextPainter(
                        text: TextSpan(text: value.text, style: inputStyle),
                        maxLines: null,
                        textDirection: Directionality.of(context),
                      )..layout(
                          maxWidth:
                              singleRowTextWidth > 0 ? singleRowTextWidth : 0,
                        );
                      final isMultiline =
                          painter.computeLineMetrics().length > 1;

                      if (isMultiline) {
                        // Field on top spanning the full width; controls on a
                        // toolbar row beneath, grouped on the right.
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textField,
                            Row(children: [const Spacer(), controls]),
                          ],
                        );
                      }

                      // One line: field and controls share a single row.
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: textField),
                          const SizedBox(width: 8),
                          controls,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Bottom-area rows (error / input / banner) share the transcript's
/// centered max-width column so everything lines up.
class _CenteredBottomRow extends StatelessWidget {
  const _CenteredBottomRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

/// The in-flight "busy" row shown while waiting for an answer. Its label is
/// mode-aware — "Answering…" in Fast, "Thinking…" in Thinking — which also
/// quietly signals the longer wait the Thinking tier takes. It reads the mode
/// pinned on the chat state at send time ([ResearchChatState.inFlightMode]), so
/// flipping the switch mid-answer never relabels the request already running.
class _BusyRow extends ConsumerWidget {
  const _BusyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode =
        ref.watch(researchChatProvider.select((s) => s.inFlightMode));
    final label = mode.busyLabel(l10n);
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
          Text(label),
        ],
      ),
    );
  }
}

/// One turn: the user's question as a right-aligned bubble; the assistant's
/// answer as flat text under a small avatar + "RESEARCH" label (mockup
/// style), with inline citation chips.
class _MessageTurn extends StatelessWidget {
  const _MessageTurn({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(message.content),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.auto_awesome,
                    size: 16, color: colors.onPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.navResearch.toUpperCase(),
                // Same muted section-header treatment as the panel's RECENT.
                style: context.typography.sectionHeader
                    .copyWith(color: colors.onSurfaceVariant),
              ),
              // Which model answered — quiet provenance for the curious.
              // Null for chats saved before the backend sent it.
              if (message.model != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '· ${message.model}',
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.sectionHeader.copyWith(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ResearchAnswerView(
            answer: message.content,
            citations: message.citations,
          ),
        ],
      ),
    );
  }
}
