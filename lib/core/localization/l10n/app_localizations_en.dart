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
}
