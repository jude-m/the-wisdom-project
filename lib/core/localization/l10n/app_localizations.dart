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

  /// Label for Pali-only reader layout
  ///
  /// In en, this message translates to:
  /// **'Pali Only'**
  String get layoutPaliOnly;

  /// Label for Sinhala-only reader layout
  ///
  /// In en, this message translates to:
  /// **'Sinhala Only'**
  String get layoutSinhalaOnly;

  /// Label for side-by-side reader layout showing both Pali and Sinhala horizontally
  ///
  /// In en, this message translates to:
  /// **'Side by Side'**
  String get layoutSideBySide;

  /// Label for stacked reader layout showing Pali and Sinhala in alternating paragraphs
  ///
  /// In en, this message translates to:
  /// **'Stacked'**
  String get layoutStacked;

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

  /// Label for the theme setting in the settings menu
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Label for the light theme option in the theme selector
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Label for the app/UI language setting (pure localization of interface labels)
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// Label for the content language setting — which text/translation is shown for data labels (tree, breadcrumbs, search, dialogs, tabs)
  ///
  /// In en, this message translates to:
  /// **'Content Language'**
  String get contentLanguage;

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

  /// Tooltip for toggle button that switches between prefix matching and exact word matching in search
  ///
  /// In en, this message translates to:
  /// **'Exact word match'**
  String get isExactMatchToggle;

  /// Title for the refine search dialog
  ///
  /// In en, this message translates to:
  /// **'Refine Search'**
  String get refineSearch;

  /// Label for the refine button/chip
  ///
  /// In en, this message translates to:
  /// **'Refine'**
  String get refine;

  /// Tooltip for the chevron button that expands the dictionary bottom sheet to full height
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get expand;

  /// Tooltip for the chevron button that collapses the dictionary bottom sheet to its minimum height
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get collapse;

  /// Label for the scope section in refine dialog
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope;

  /// Header above the Pali/Sinhala toggle in the Refine Search dialog that chooses which language(s) the search looks in
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get searchLanguageLabel;

  /// Search results tab + section header: combined best matches across all categories
  ///
  /// In en, this message translates to:
  /// **'Top Results'**
  String get searchTabTopResults;

  /// Search results tab + section header: matches in sutta/section/commentary titles
  ///
  /// In en, this message translates to:
  /// **'Titles'**
  String get searchTabTitles;

  /// Search results tab + section header: matches in the body content of texts
  ///
  /// In en, this message translates to:
  /// **'Full text'**
  String get searchTabFullText;

  /// Search results tab + section header: dictionary definition matches
  ///
  /// In en, this message translates to:
  /// **'Definitions'**
  String get searchTabDefinitions;

  /// Header above the list of the user's recent search queries
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// Expand link revealing additional secondary matches from the same text
  ///
  /// In en, this message translates to:
  /// **'View {count} more'**
  String viewMore(int count);

  /// Collapse link that hides the expanded secondary matches again
  ///
  /// In en, this message translates to:
  /// **'Show Less'**
  String get showLess;

  /// Label for the word proximity section in refine dialog
  ///
  /// In en, this message translates to:
  /// **'Word Proximity'**
  String get wordProximity;

  /// Label for phrase search checkbox
  ///
  /// In en, this message translates to:
  /// **'Phrase search (exact consecutive words)'**
  String get phraseSearch;

  /// Label showing proximity distance
  ///
  /// In en, this message translates to:
  /// **'{count} words apart'**
  String wordsApart(int count);

  /// Label shown when phrase search is enabled
  ///
  /// In en, this message translates to:
  /// **'Exact consecutive words'**
  String get exactConsecutiveWords;

  /// Button label to apply changes
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Button label to reset to defaults
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Button label to clear selections
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Label for the action that clears all recent searches
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// Label for 'All' scope chip (no filter)
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get scopeAll;

  /// Label for Sutta Pitaka scope chip
  ///
  /// In en, this message translates to:
  /// **'Sutta'**
  String get scopeSutta;

  /// Label for Vinaya Pitaka scope chip
  ///
  /// In en, this message translates to:
  /// **'Vinaya'**
  String get scopeVinaya;

  /// Label for Abhidhamma Pitaka scope chip
  ///
  /// In en, this message translates to:
  /// **'Abhidhamma'**
  String get scopeAbhidhamma;

  /// Label for Commentaries (Atthakatha) scope chip
  ///
  /// In en, this message translates to:
  /// **'Commentaries'**
  String get scopeCommentaries;

  /// Label for Treatises scope chip
  ///
  /// In en, this message translates to:
  /// **'Treatises'**
  String get scopeTreatises;

  /// Radio button label for phrase search mode (words must be adjacent)
  ///
  /// In en, this message translates to:
  /// **'Search as complete phrase'**
  String get searchAsPhrase;

  /// Radio button label for separate-word search mode (words within proximity)
  ///
  /// In en, this message translates to:
  /// **'Search as separate words'**
  String get searchAsSeparateWords;

  /// Checkbox label to search words anywhere in the text without proximity constraint
  ///
  /// In en, this message translates to:
  /// **'Anywhere in the same text'**
  String get anywhereInText;

  /// Message shown when dictionary lookup returns no results
  ///
  /// In en, this message translates to:
  /// **'No definitions found'**
  String get noDefinitionsFound;

  /// Title for dictionary lookup feature
  ///
  /// In en, this message translates to:
  /// **'Dictionary'**
  String get dictionaryLookup;

  /// Error message when dictionary lookup fails
  ///
  /// In en, this message translates to:
  /// **'Error loading definitions'**
  String get errorLoadingDefinitions;

  /// Label for button to navigate to commentary (atthakatha) of current text
  ///
  /// In en, this message translates to:
  /// **'Commentary'**
  String get commentary;

  /// Label for button to navigate to root text (sutta) from commentary
  ///
  /// In en, this message translates to:
  /// **'Root Text'**
  String get rootText;

  /// Tooltip for button to scroll to the beginning of the sutta when opened mid-document from FTS
  ///
  /// In en, this message translates to:
  /// **'Go to beginning'**
  String get scrollToBeginning;

  /// Tooltip for button to navigate to the previous sutta in tree order
  ///
  /// In en, this message translates to:
  /// **'Go to: {name}'**
  String goToPreviousSutta(String name);

  /// Placeholder text for the in-page search text field
  ///
  /// In en, this message translates to:
  /// **'Find in page'**
  String get findInPage;

  /// Shown when in-page search finds no matches
  ///
  /// In en, this message translates to:
  /// **'0 / 0'**
  String get noInPageMatches;

  /// Tooltip for previous match button in in-page search
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get previousMatch;

  /// Tooltip for next match button in in-page search
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get nextMatch;

  /// Tooltip for the backspace key on the dictionary search keyboard
  ///
  /// In en, this message translates to:
  /// **'Backspace'**
  String get backspace;

  /// Label for 'All' dictionary filter chip (no filter)
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get dictFilterAll;

  /// Label for Sinhala dictionary filter chip
  ///
  /// In en, this message translates to:
  /// **'Sinhala'**
  String get dictFilterSinhala;

  /// Label for English dictionary filter chip
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get dictFilterEnglish;

  /// Title for the refine dictionaries dialog
  ///
  /// In en, this message translates to:
  /// **'Refine Dictionaries'**
  String get dictRefineTitle;

  /// Section label in the refine dictionaries dialog
  ///
  /// In en, this message translates to:
  /// **'DICTIONARIES'**
  String get dictRefineSectionLabel;

  /// Button label to dismiss a dialog after completing changes
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Label for the DPD dictionary 'Read more' link
  ///
  /// In en, this message translates to:
  /// **'Read more'**
  String get readMore;

  /// Error message shown when a URL cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Could not open link'**
  String get couldNotOpenLink;

  /// Title shown in any panel when the server is unreachable (no network, timeout, etc.)
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server'**
  String get statusOfflineTitle;

  /// Supporting line shown under statusOfflineTitle
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get statusOfflineDescription;

  /// Specific error title shown in the search panel when a non-network failure occurs
  ///
  /// In en, this message translates to:
  /// **'Error loading results'**
  String get errorLoadingSearch;

  /// Supporting line shown under each panel-specific error title (errorLoadingSearch, errorLoadingTree, errorLoadingContent, errorLoadingDefinitions).
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get statusErrorDescription;

  /// Shown in the search panel when the query is empty or otherwise invalid
  ///
  /// In en, this message translates to:
  /// **'Enter a valid search query'**
  String get statusInvalidQuery;

  /// Empty state for a specific search category tab
  ///
  /// In en, this message translates to:
  /// **'No {category} found'**
  String statusNoResultsForCategory(String category);

  /// Empty state shown in the reader before any sutta has been selected
  ///
  /// In en, this message translates to:
  /// **'Select a sutta from the tree to begin reading'**
  String get statusSelectSuttaToRead;

  /// Empty state shown in the reader when the loaded document has no pages in range
  ///
  /// In en, this message translates to:
  /// **'No content to display'**
  String get statusNoContentToDisplay;

  /// Empty state shown in the navigation tree when no root nodes exist
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get statusNoTreeContent;

  /// Title text of the banner shown when a fresher app build is live on the server
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateBannerTitle;

  /// Tappable text in the update banner that reloads the page to pick up the new version
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get updateBannerRefreshAction;

  /// Tooltip on the close (×) icon of the update banner
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get updateBannerDismissTooltip;
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
