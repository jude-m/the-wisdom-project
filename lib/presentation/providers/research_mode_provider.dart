import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/research/research_mode.dart';

/// Holds the [ResearchMode] (Fast / Thinking) currently shown in the Research
/// header — the tier the *next* question will be sent under.
///
/// This is an in-memory cursor, **not** a persisted global setting. Its value
/// is seeded by the chat lifecycle, not restored from disk:
/// - starting a **new chat** resets it to [ResearchMode.fast] (the default),
/// - **opening a saved chat** sets it to that chat's last-used tier.
///
/// The per-chat tier is what actually persists — it rides the chat's
/// `ChatSummary` in local storage (see [ChatHistoryRepository]). Keeping this
/// provider transient is why a fresh chat (or an app restart, which starts on a
/// fresh chat) always begins on Fast regardless of what was picked before.
///
/// [ResearchChatNotifier] reads it at send time to pick the tier and to stamp
/// it onto the chat's summary.
class ResearchModeNotifier extends StateNotifier<ResearchMode> {
  ResearchModeNotifier() : super(ResearchMode.fast);

  /// Set the active tier — the mode switch, and the new-chat/open-chat seeding.
  void set(ResearchMode mode) => state = mode;
}

/// App-wide provider for the Research Fast/Thinking mode. In-memory only; see
/// [ResearchModeNotifier] for why it isn't persisted.
final researchModeProvider =
    StateNotifierProvider<ResearchModeNotifier, ResearchMode>((ref) {
  return ResearchModeNotifier();
});
