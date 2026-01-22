import 'package:flutter/material.dart';

/// Static metadata about available dictionaries
@immutable
class DictionaryInfo {
  final String id;
  final String name;
  final String abbreviation;
  final String targetLanguage;

  const DictionaryInfo({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.targetLanguage,
  });

  /// All available dictionaries with metadata
  /// Ordered by typical display priority
  static const Map<String, DictionaryInfo> all = {
    // Sinhala target dictionaries
    'BUS': DictionaryInfo(
      id: 'BUS',
      name: 'Buddhadatta (Sinhala)',
      abbreviation: 'BUS',
      targetLanguage: 'si',
    ),
    'MS': DictionaryInfo(
      id: 'MS',
      name: 'Sumangala',
      abbreviation: 'MS',
      targetLanguage: 'si',
    ),

    // English target dictionaries
    'BUE': DictionaryInfo(
      id: 'BUE',
      name: 'Buddhadatta (English)',
      abbreviation: 'BUE',
      targetLanguage: 'en',
    ),
    'DPD': DictionaryInfo(
      id: 'DPD',
      name: 'Digital Pali Dictionary',
      abbreviation: 'DPD',
      targetLanguage: 'en',
    ),
    'VRI': DictionaryInfo(
      id: 'VRI',
      name: 'Vipassana Research Institute',
      abbreviation: 'VRI',
      targetLanguage: 'en',
    ),
    'PTS': DictionaryInfo(
      id: 'PTS',
      name: 'Pali Text Society',
      abbreviation: 'PTS',
      targetLanguage: 'en',
    ),
    'CR': DictionaryInfo(
      id: 'CR',
      name: 'Critical Pali Dictionary',
      abbreviation: 'CR',
      targetLanguage: 'en',
    ),
    'DPDC': DictionaryInfo(
      id: 'DPDC',
      name: 'DPD Construction',
      abbreviation: 'DPDC',
      targetLanguage: 'en',
    ),
    'ND': DictionaryInfo(
      id: 'ND',
      name: 'Nyanatiloka Dictionary',
      abbreviation: 'ND',
      targetLanguage: 'en',
    ),
    'PN': DictionaryInfo(
      id: 'PN',
      name: 'Dictionary of Pali Proper Names',
      abbreviation: 'PN',
      targetLanguage: 'en',
    ),
  };

  /// Get info for a dictionary by ID, returns null if not found
  static DictionaryInfo? getById(String id) => all[id];

  /// Get display name for a dictionary ID
  static String getDisplayName(String id) =>
      all[id]?.name ?? id;

  /// Get abbreviation for a dictionary ID
  static String getAbbreviation(String id) =>
      all[id]?.abbreviation ?? id;

  /// Returns the color associated with a dictionary ID for UI display
  ///
  /// Each dictionary has a distinctive color used in badges and UI elements.
  /// Returns the theme's primary color as fallback if the dictionary is not found.
  static Color getColor(String dictId, ThemeData theme) {
    return switch (dictId) {
      'DPD' => Colors.blue,
      'PTS' => Colors.purple,
      'BUS' || 'BUE' => Colors.green,
      'MS' => Colors.teal,
      'VRI' => Colors.orange,
      'CR' => Colors.red,
      'DPDC' => Colors.indigo,
      'ND' => Colors.brown,
      'PN' => Colors.amber,
      _ => theme.colorScheme.primary,
    };
  }
}
