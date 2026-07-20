import 'package:freezed_annotation/freezed_annotation.dart';

part 'citation.freezed.dart';
part 'citation.g.dart';

/// A single source the AI answer is grounded on.
///
/// Mapped from the backend's `grounding_metadata` — see the `/research` contract in
/// `docs/todo/wisdom-project-rag-qa-design.md` §5.5 and §7.
@freezed
class Citation with _$Citation {
  const factory Citation({
    /// SuttaCentral uid, e.g. "sn15.3" or "pli-tv-bu-vb-np18".
    required String uid,

    /// Human-readable reference shown to the user, e.g. "SN 15.3".
    required String ref,

    /// Sutta heading minus the ref prefix, e.g. "Chapter One A Mustard Seed".
    /// Shown bold next to [ref]; null when the chunk carried no heading.
    String? title,

    /// "canon" today; "note" reserved for Sujato's notes (design §5.2).
    /// Kept from day one so adding notes later needs no contract change.
    @Default('canon') String kind,

    /// SuttaCentral English source span that grounded this point — the "why it
    /// was cited" provenance shown in the peek sheet. Matched query terms are
    /// wrapped in `**…**` (rendered bold); see `make_snippet` on the server.
    /// Deep links are NOT on the wire (`deeplink` removed 2026-07-18 — the
    /// server could never resolve them): the app resolves [uid] → BJT nodeKey
    /// client-side via the shared resolver.
    String? snippet,
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);
}
