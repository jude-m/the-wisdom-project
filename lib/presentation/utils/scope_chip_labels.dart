import '../../core/localization/l10n/app_localizations.dart';
import '../../domain/entities/search/search_scope_chip.dart';

/// Resolves a [SearchScopeChip]'s localized label in the presentation layer.
///
/// The chip itself (domain) holds only its stable [SearchScopeChip.id]; the
/// label is a UI concern, so the id → l10n string mapping lives here. This is
/// what keeps `search_scope_chip.dart` Flutter-free.
String scopeChipLabel(SearchScopeChip chip, AppLocalizations l10n) =>
    switch (chip.id) {
      'sutta' => l10n.scopeSutta,
      'vinaya' => l10n.scopeVinaya,
      'abhidhamma' => l10n.scopeAbhidhamma,
      'commentaries' => l10n.scopeCommentaries,
      'treatises' => l10n.scopeTreatises,
      _ => chip.id,
    };
