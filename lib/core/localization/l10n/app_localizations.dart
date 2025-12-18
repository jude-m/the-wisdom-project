import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_si.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('si')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'The Wisdom Project'**
  String get appTitle;

  /// Title for the tree navigation screen
  ///
  /// In en, this message translates to:
  /// **'Tipitaka Navigator'**
  String get treeNavigatorTitle;

  /// Title for the reading screen
  ///
  /// In en, this message translates to:
  /// **'Reader'**
  String get readerTitle;

  /// Label for Pali-only column display mode
  ///
  /// In en, this message translates to:
  /// **'Pali Only'**
  String get columnModePaliOnly;

  /// Label for Sinhala-only column display mode
  ///
  /// In en, this message translates to:
  /// **'Sinhala Only'**
  String get columnModeSinhalaOnly;

  /// Label for dual-column display mode showing both Pali and Sinhala
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get columnModeBoth;

  /// Label for Pali language
  ///
  /// In en, this message translates to:
  /// **'Pali'**
  String get paliLanguageLabel;

  /// Label for Sinhala language
  ///
  /// In en, this message translates to:
  /// **'Sinhala'**
  String get sinhalaLanguageLabel;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message when content fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading content'**
  String get errorLoadingContent;

  /// Error message when navigation tree fails to load
  ///
  /// In en, this message translates to:
  /// **'Error loading navigation tree'**
  String get errorLoadingTree;

  /// Button label to retry a failed operation
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Placeholder message shown when no content is selected
  ///
  /// In en, this message translates to:
  /// **'Select a sutta from the navigator to begin reading'**
  String get selectNodeToRead;

  /// Placeholder text for search input
  ///
  /// In en, this message translates to:
  /// **'Search Tipitaka...'**
  String get searchPlaceholder;

  /// Message shown when search returns no results
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// Button label to expand all tree nodes
  ///
  /// In en, this message translates to:
  /// **'Expand All'**
  String get expandAll;

  /// Button label to collapse all tree nodes
  ///
  /// In en, this message translates to:
  /// **'Collapse All'**
  String get collapseAll;

  /// Label for settings menu
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Label for navigation language setting
  ///
  /// In en, this message translates to:
  /// **'Navigation Language'**
  String get navigationLanguage;

  /// Label for font size setting
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// Label for small font size option
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get fontSizeSmall;

  /// Label for medium font size option
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get fontSizeMedium;

  /// Label for large font size option
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get fontSizeLarge;

  /// Label for extra large font size option
  ///
  /// In en, this message translates to:
  /// **'Extra Large'**
  String get fontSizeExtraLarge;

  /// Button label to close a dialog or screen
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Hint text shown in search input field
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'si'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'si':
      return AppLocalizationsSi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
