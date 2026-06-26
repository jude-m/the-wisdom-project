import 'package:freezed_annotation/freezed_annotation.dart';

part 'citation.freezed.dart';
part 'citation.g.dart';

/// A single source the AI answer is grounded on.
///
/// Mapped from the backend's `grounding_metadata` — see the `/ask` contract in
/// `docs/todo/wisdom-project-rag-qa-design.md` §5.5 and §7.
@freezed
class Citation with _$Citation {
  const factory Citation({
    /// SuttaCentral uid, e.g. "sn15.3" or "pli-tv-bu-vb-np18".
    required String uid,

    /// Human-readable reference shown to the user, e.g. "SN 15.3".
    required String ref,

    /// "canon" today; "note" reserved for Sujato's notes (design §5.2).
    /// Kept from day one so adding notes later needs no contract change.
    @Default('canon') String kind,

    /// English source span used to ground this point (doubles as the
    /// verification preview the deep link would open).
    String? snippet,

    /// In-app deep link. Null until the SuttaCentral→BJT resolver lands
    /// (see the resolver plan, Part D). Not rendered as a tappable link in v1.
    String? deeplink,
  }) = _Citation;

  factory Citation.fromJson(Map<String, dynamic> json) =>
      _$CitationFromJson(json);
}
