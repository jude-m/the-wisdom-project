import '../../core/utils/pali_conjunct_transformer.dart';
import '../../domain/entities/content/content_language.dart';

/// Turns a raw content string into its display form for the selected
/// [ContentLanguage]. This is the single "pipeline" seam for label rendering:
/// every data-label surface (tree, breadcrumbs, search, dialogs, tabs) routes
/// through it instead of calling `.withPaliConjuncts` directly.
///
/// Today it only applies Pali conjunct ligatures — i.e. Pali shown in *Sinhala
/// script*. When the Pali→Roman transliteration library lands (Phase 2), the
/// [ContentLanguage.pali] branch is where it plugs in (based on the selected
/// Pali script), so no caller has to change.
///
/// Conjuncts must NEVER be applied to a Sinhala translation — that would
/// incorrectly bind consonants — hence the explicit per-language switch.
String formatContentLabel(String raw, ContentLanguage language) {
  switch (language) {
    case ContentLanguage.pali:
      return raw.withPaliConjuncts;
    case ContentLanguage.sinhala:
      return raw;
  }
}
