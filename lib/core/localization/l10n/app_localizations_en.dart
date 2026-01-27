// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The Wisdom Project';

  @override
  String get treeNavigatorTitle => 'Tipitaka Navigator';

  @override
  String get readerTitle => 'Reader';

  @override
  String get columnModePaliOnly => 'Pali Only';

  @override
  String get columnModeSinhalaOnly => 'Sinhala Only';

  @override
  String get columnModeBoth => 'Both';

  @override
  String get paliLanguageLabel => 'Pali';

  @override
  String get sinhalaLanguageLabel => 'Sinhala';

  @override
  String get loading => 'Loading...';

  @override
  String get errorLoadingContent => 'Error loading content';

  @override
  String get errorLoadingTree => 'Error loading navigation tree';

  @override
  String get retry => 'Retry';

  @override
  String get selectNodeToRead =>
      'Select a sutta from the navigator to begin reading';

  @override
  String get searchPlaceholder => 'Search Tipitaka...';

  @override
  String get noResultsFound => 'No results found';

  @override
  String get expandAll => 'Expand All';

  @override
  String get collapseAll => 'Collapse All';

  @override
  String get settings => 'Settings';

  @override
  String get navigationLanguage => 'Navigation Language';

  @override
  String get fontSize => 'Font Size';

  @override
  String get fontSizeSmall => 'Small';

  @override
  String get fontSizeMedium => 'Medium';

  @override
  String get fontSizeLarge => 'Large';

  @override
  String get fontSizeExtraLarge => 'Extra Large';

  @override
  String get close => 'Close';

  @override
  String get searchHint => 'Search';

  @override
  String get isExactMatchToggle => 'Exact word match';

  @override
  String get refineSearch => 'Refine Search';

  @override
  String get refine => 'Refine';

  @override
  String get scope => 'Scope';

  @override
  String get wordProximity => 'Word Proximity';

  @override
  String get phraseSearch => 'Phrase search (exact consecutive words)';

  @override
  String wordsApart(int count) {
    return '$count words apart';
  }

  @override
  String get exactConsecutiveWords => 'Exact consecutive words';

  @override
  String get apply => 'Apply';

  @override
  String get reset => 'Reset';

  @override
  String get clear => 'Clear';

  @override
  String get scopeAll => 'All';

  @override
  String get scopeSutta => 'Sutta';

  @override
  String get scopeVinaya => 'Vinaya';

  @override
  String get scopeAbhidhamma => 'Abhidhamma';

  @override
  String get scopeCommentaries => 'Commentaries';

  @override
  String get scopeTreatises => 'Treatises';

  @override
  String get searchAsPhrase => 'Search as complete phrase';

  @override
  String get searchAsSeparateWords => 'Search as separate words';

  @override
  String get anywhereInText => 'Anywhere in the same text';

  @override
  String get noDefinitionsFound => 'No definitions found';

  @override
  String get dictionaryLookup => 'Dictionary';

  @override
  String get errorLoadingDefinitions => 'Error loading definitions';

  @override
  String get commentary => 'Commentary';

  @override
  String get rootText => 'Root Text';
}
