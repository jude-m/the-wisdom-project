import '../../core/utils/pali_conjunct_transformer.dart';
import '../../core/utils/pali_letter_options.dart';
import '../../domain/entities/content/content_language.dart';

/// Turns a raw content string into its display form for the selected
/// [ContentLanguage]. This is the single "pipeline" seam for label rendering:
/// every data-label surface (tree, breadcrumbs, search, dialogs, tabs) routes
/// through it instead of calling the transformer directly.
///
/// [options] are the three Pali-letter switches (usually sourced from
/// `paliLetterOptionsProvider`). They only affect the Pali branch.
///
/// When the Pali→Roman transliteration library lands (Phase 2), the
/// [ContentLanguage.pali] branch is where it plugs in (based on the selected
/// Pali script), so no caller has to change.
///
/// Conjuncts must NEVER be applied to a Sinhala translation — that would
/// incorrectly bind consonants — hence the explicit per-language switch.
String formatContentLabel(
  String raw,
  ContentLanguage language,
  PaliLetterOptions options,
) {
  switch (language) {
    case ContentLanguage.pali:
      return beautifyPaliText(raw, options);
    case ContentLanguage.sinhala:
      return raw;
  }
}
