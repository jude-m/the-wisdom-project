/// Which model tier answers a research question — the app's Fast/Thinking
/// switch, chosen by the user in the Research header.
///
/// Sent to the `/research` backend as the `mode` field; the server maps it to a
/// model ladder (`config.models_for_mode`: fast → the flash-lite tier, thinking
/// → the full-flash tier). Plain enum on purpose — the client only ever *sends*
/// a mode, so there's no JSON/Freezed codegen to carry.
enum ResearchMode {
  /// Flash-lite tier: fastest answers, most generous free quota. The default.
  fast,

  /// Full-flash tier: deeper reasoning, at the cost of a longer wait.
  thinking;

  /// The wire value the backend's `mode` field expects ("fast" | "thinking").
  /// It's just the enum name, so the two stay in lockstep with no mapping.
  String get wire => name;
}
