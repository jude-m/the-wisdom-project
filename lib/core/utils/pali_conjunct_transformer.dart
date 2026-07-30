/// Moved to `package:wisdom_shared/src/text/pali_conjuncts.dart`.
///
/// The static-site generator has to bake the *same* conjuncts into its HTML
/// that the reader renders (build plan D1), and it cannot import anything from
/// `lib/`. The implementation is Flutter-free, so it moved wholesale rather
/// than being copied — a second copy would drift and the two surfaces would
/// disagree about how a cluster joins.
///
/// This file stays as a re-export so the 20-odd existing importers (and their
/// tests) keep working unchanged. Import `package:wisdom_shared/wisdom_shared.dart`
/// directly in new code.
library;

export 'package:wisdom_shared/wisdom_shared.dart'
    show
        PaliConjunctExtension,
        addCommonConjuncts,
        addRakaransaya,
        addRepaya,
        addSpecialConjuncts,
        addTouchingConjuncts,
        addYansaya,
        applyConjunctsWithRangeMapping,
        beautifyPaliText,
        buildConjunctPositionMap,
        removeConjunctFormatting,
        shortenVowels;
