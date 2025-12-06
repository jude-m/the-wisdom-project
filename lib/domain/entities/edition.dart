import 'package:freezed_annotation/freezed_annotation.dart';

part 'edition.freezed.dart';

/// Represents a complete Tipitaka edition (e.g., BJT, SuttaCentral, PTS)
///
/// An edition is a specific publication or digitization of the Pali Canon.
/// Different editions may have different texts, translations, pagination, and metadata.
@freezed
class Edition with _$Edition {
  const factory Edition({
    /// Unique identifier for this edition
    /// Examples: 'bjt', 'suttacentral', 'pts'
    required String editionId,

    /// Human-readable display name
    /// Examples: 'Buddha Jayanti Tripitaka', 'SuttaCentral', 'Pali Text Society'
    required String displayName,

    /// Short abbreviation for UI display
    /// Examples: 'BJT', 'SC', 'PTS'
    required String abbreviation,

    /// Type of edition (local files vs remote API)
    required EditionType type,

    /// Language codes available in this edition
    /// Uses ISO 639-1 codes: 'pi' (Pali), 'si' (Sinhala), 'en' (English), etc.
    @Default([]) List<String> availableLanguages,
  }) = _Edition;
}

/// Defines where the edition data comes from
enum EditionType {
  /// Edition is stored locally in the app bundle or device storage
  /// Example: BJT JSON files bundled with the app
  local,

  /// Edition is fetched from a remote API
  /// Example: SuttaCentral bilara-data from GitHub
  remote,
}
