import 'package:freezed_annotation/freezed_annotation.dart';
import 'entry.dart';
import 'bjt/bjt_document.dart';

part 'text_layer.freezed.dart';

/// Represents a single language/edition/script rendition of a text
///
/// A TextLayer is a specific combination of edition, language, and script.
/// Examples:
/// - BJT Pali in Sinhala script (editionId: 'bjt', languageCode: 'pi', scriptCode: 'sinh')
/// - BJT Pali in Roman script (editionId: 'bjt', languageCode: 'pi', scriptCode: 'latn')
/// - BJT Sinhala (editionId: 'bjt', languageCode: 'si', scriptCode: 'sinh')
/// - SuttaCentral English by Sujato (editionId: 'suttacentral', languageCode: 'en', scriptCode: 'latn', translator: 'Bhikkhu Sujato')
///
/// TextLayers flatten the page-based structure into a sequential list of segments
/// for easier alignment across different editions.
@freezed
class TextLayer with _$TextLayer {
  const TextLayer._();

  const factory TextLayer({
    /// Unique identifier for this layer
    /// Format: "{editionId}-{languageCode}-{scriptCode}[-{translator}]"
    /// Examples: 'bjt-pi-sinh', 'bjt-pi-latn', 'bjt-si-sinh', 'sc-en-latn-sujato'
    required String layerId,

    /// Edition this layer belongs to ('bjt', 'suttacentral', 'pts')
    required String editionId,

    /// ISO 639-1 language code ('pi', 'si', 'en', etc.)
    required String languageCode,

    /// ISO 15924 script code
    /// - 'sinh' = Sinhala script (සද්ධම්මං)
    /// - 'latn' = Latin/Roman script (Saddhammaṁ)
    /// - 'thai' = Thai script (สัทธัมมัง)
    /// - 'deva' = Devanagari script (सद्धम्मं)
    /// - 'mymr' = Myanmar/Burmese script
    required String scriptCode,

    /// Translator name (optional, primarily for SuttaCentral)
    /// Examples: 'Bhikkhu Sujato', 'Bhikkhu Bodhi'
    String? translator,

    /// Flattened list of entries across all pages
    /// This removes the page structure to enable easier cross-edition alignment
    @Default([]) List<Entry> segments,
  }) = _TextLayer;

  /// Display name for this layer
  /// Examples:
  /// - "BJT Pali (සිංහල)"
  /// - "BJT Pali (Roman)"
  /// - "BJT සිංහල"
  /// - "SC English (Sujato)"
  String get displayName {
    final langName = _getLanguageName(languageCode);
    final edName = _getEditionAbbreviation(editionId);
    final scriptName = _getScriptName(scriptCode, languageCode);

    final baseName = '$edName $langName';

    // Add script indicator if the script is non-native for this language
    final needsScriptIndicator = _isNonNativeScript(languageCode, scriptCode);
    final nameWithScript = needsScriptIndicator ? '$baseName ($scriptName)' : baseName;

    // Add translator if present
    if (translator != null) {
      return '$nameWithScript ($translator)';
    }
    return nameWithScript;
  }

  /// Helper to get language display name
  String _getLanguageName(String code) {
    switch (code) {
      case 'pi':
        return 'Pali';
      case 'si':
        return 'සිංහල';
      case 'en':
        return 'English';
      case 'de':
        return 'German';
      case 'pt':
        return 'Portuguese';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      default:
        return code.toUpperCase();
    }
  }

  /// Helper to get edition abbreviation
  String _getEditionAbbreviation(String id) {
    switch (id) {
      case 'bjt':
        return 'BJT';
      case 'suttacentral':
      case 'sc':
        return 'SC';
      case 'pts':
        return 'PTS';
      default:
        return id.toUpperCase();
    }
  }

  /// Helper to get script display name
  String _getScriptName(String code, String languageCode) {
    switch (code) {
      case 'sinh':
        return 'සිංහල';
      case 'latn':
        return 'Roman';
      case 'thai':
        return 'Thai';
      case 'deva':
        return 'Devanagari';
      case 'mymr':
        return 'Myanmar';
      default:
        return code.toUpperCase();
    }
  }

  /// Check if this is a non-native script for the language
  /// (e.g., Pali in Roman is non-native since Pali is native to Sinhala/Thai/etc.)
  bool _isNonNativeScript(String lang, String script) {
    // Pali can be written in multiple scripts - show script indicator unless it's Sinhala (default)
    if (lang == 'pi') {
      return script != 'sinh'; // BJT uses Sinhala as default
    }

    // Sinhala is always Sinhala script
    if (lang == 'si') {
      return false; // Don't show script for native Sinhala
    }

    // English is always Latin
    if (lang == 'en') {
      return false;
    }

    // Default: show script if it's not Latin
    return script != 'latn';
  }

  /// Total number of segments in this layer
  int get segmentCount => segments.length;

  /// Check if this layer has any segments
  bool get hasSegments => segments.isNotEmpty;
}

/// Extension to convert BJTDocument to TextLayers
/// This is the bridge between the page-based BJT structure and the segment-based layer structure
extension BJTDocumentToLayers on BJTDocument {
  /// Converts page-based BJTDocument into separate TextLayers for each language
  ///
  /// For BJT, this creates two layers:
  /// 1. BJT Pali in Sinhala script - with all Pali entries flattened
  /// 2. BJT Sinhala - with all Sinhala entries flattened
  ///
  /// Both layers have identical segment counts and aligned segment IDs,
  /// allowing perfect parallel text display.
  ///
  /// Note: BJT stores Pali in Sinhala script natively. To show Pali in Roman script,
  /// you would need to apply script conversion (transliteration) to create a new layer.
  List<TextLayer> toTextLayers() {
    // Flatten Pali entries from all pages
    final paliSegments = <Entry>[];
    final sinhalaSegments = <Entry>[];

    for (final page in pages) {
      paliSegments.addAll(page.paliSection.entries);
      sinhalaSegments.addAll(page.sinhalaSection.entries);
    }

    return [
      TextLayer(
        layerId: '$fileId-pi-sinh',
        editionId: editionId,
        languageCode: 'pi',
        scriptCode: 'sinh', // BJT stores Pali in Sinhala script
        segments: paliSegments,
      ),
      TextLayer(
        layerId: '$fileId-si-sinh',
        editionId: editionId,
        languageCode: 'si',
        scriptCode: 'sinh',
        segments: sinhalaSegments,
      ),
    ];
  }
}
