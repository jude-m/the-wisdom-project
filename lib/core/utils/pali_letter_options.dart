/// Immutable holder for the three Pali-letter display switches.
///
/// Threaded as a single object through every text-rendering seam (the reading
/// pane and all content-language labels — tree, breadcrumbs, tabs, search,
/// dialogs) so one `ref.watch(paliLetterOptionsProvider)` drives them all.
///
/// The three switches are **independent typographic systems**, not strength
/// levels of one effect — see
/// `docs/pali-letter-settings-bandi-special-toggles.md`.
class PaliLetterOptions {
  const PaliLetterOptions({
    required this.standardLigatures, // Switch 3
    required this.specialConjuncts, // Switch 2
    required this.touching, // Switch 1
  });

  /// **Switch 3** — rakaransaya + yansaya + repaya + the 8 common pairs.
  /// Ligated mechanism (`hal + ZWJ`). Default ON.
  final bool standardLigatures;

  /// **Switch 2** — the 7 rare old-Pali ligatures that need UN-type fonts.
  /// Ligated mechanism (`hal + ZWJ`). Default OFF.
  final bool specialConjuncts;

  /// **Switch 1** — the productive "touching" rule for every remaining cluster
  /// plus long→short vowel shortening. Touching mechanism (`ZWJ + hal`).
  /// Default ON.
  final bool touching;

  /// App default = behavioural parity with tipitaka.lk (plan grid row 1):
  /// standard ligatures + touching on, special off.
  static const defaults = PaliLetterOptions(
    standardLigatures: true,
    specialConjuncts: false,
    touching: true,
  );

  /// Everything off — bare baseline (a visible hal on every cluster).
  static const baseline = PaliLetterOptions(
    standardLigatures: false,
    specialConjuncts: false,
    touching: false,
  );

  // Value equality so the combined Provider de-dupes rebuilds when the
  // underlying flags haven't actually changed.
  @override
  bool operator ==(Object other) =>
      other is PaliLetterOptions &&
      other.standardLigatures == standardLigatures &&
      other.specialConjuncts == specialConjuncts &&
      other.touching == touching;

  @override
  int get hashCode =>
      Object.hash(standardLigatures, specialConjuncts, touching);

  @override
  String toString() =>
      'PaliLetterOptions(standardLigatures: $standardLigatures, '
      'specialConjuncts: $specialConjuncts, touching: $touching)';
}
