// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Sinhala Sinhalese (`si`).
class AppLocalizationsSi extends AppLocalizations {
  AppLocalizationsSi([String locale = 'si']) : super(locale);

  @override
  String get appTitle => 'ප්‍රඥා ව්‍යාපෘතිය';

  @override
  String get treeNavigatorTitle => 'ත්‍රිපිටක සංචාලකය';

  @override
  String get readerTitle => 'පාඨකය';

  @override
  String get columnModePaliOnly => 'පාලි පමණයි';

  @override
  String get columnModeSinhalaOnly => 'සිංහල පමණයි';

  @override
  String get columnModeBoth => 'දෙකම';

  @override
  String get paliLanguageLabel => 'පාලි';

  @override
  String get sinhalaLanguageLabel => 'සිංහල';

  @override
  String get loading => 'පූරණය වෙමින්...';

  @override
  String get errorLoadingContent => 'අන්තර්ගතය පූරණය කිරීමේ දෝෂයකි';

  @override
  String get errorLoadingTree => 'සංචාලන ව්‍යූහය පූරණය කිරීමේ දෝෂයකි';

  @override
  String get retry => 'යළි උත්සාහ කරන්න';

  @override
  String get selectNodeToRead =>
      'කියවීම ආරම්භ කිරීමට සංචාලකයෙන් සූත්‍රයක් තෝරන්න';

  @override
  String get searchPlaceholder => 'ත්‍රිපිටකයේ සොයන්න...';

  @override
  String get noResultsFound => 'ප්‍රතිඵල හමු නොවීය';

  @override
  String get expandAll => 'සියල්ල විශාල කරන්න';

  @override
  String get collapseAll => 'සියල්ල හකුළන්න';

  @override
  String get settings => 'සැකසීම්';

  @override
  String get navigationLanguage => 'සංචාලන භාෂාව';

  @override
  String get fontSize => 'අක්ෂර ප්‍රමාණය';

  @override
  String get fontSizeSmall => 'කුඩා';

  @override
  String get fontSizeMedium => 'මධ්‍යම';

  @override
  String get fontSizeLarge => 'විශාල';

  @override
  String get fontSizeExtraLarge => 'අතිශය විශාල';

  @override
  String get close => 'වසන්න';

  @override
  String get searchHint => 'සෙවුම් පදය ඇතුලත් කරන්න';

  @override
  String get isExactMatchToggle => 'එම වචනයම සොයන්න';

  @override
  String get refineSearch => 'සූක්ෂම සෙවීම';

  @override
  String get refine => 'සූක්ෂම';

  @override
  String get scope => 'පරාසය';

  @override
  String get wordProximity => 'වචන ආසන්නතාව';

  @override
  String get phraseSearch => 'වාක්‍ය ඛණ්ඩ සෙවීම (පිළිවෙලට ඇති වචන)';

  @override
  String wordsApart(int count) {
    return 'වචන $countක් පරතරයකින්';
  }

  @override
  String get exactConsecutiveWords => 'හරියටම පිළිවෙලට ඇති වචන';

  @override
  String get apply => 'යොදන්න';

  @override
  String get reset => 'යළි සකසන්න';

  @override
  String get clear => 'ඉවත් කරන්න';

  @override
  String get scopeAll => 'සියල්ල';

  @override
  String get scopeSutta => 'සුත්ත';

  @override
  String get scopeVinaya => 'විනය';

  @override
  String get scopeAbhidhamma => 'අභිධම්ම';

  @override
  String get scopeCommentaries => 'අට්ඨකථා';

  @override
  String get scopeTreatises => 'ග්‍රන්ථ';

  @override
  String get searchAsPhrase => 'සම්පුර්ණ වාක්‍යක් ලෙස';

  @override
  String get searchAsSeparateWords => 'වෙන්වූ වචන සමූහයක් ලෙස';

  @override
  String get anywhereInText => 'එකම පෙළෙහි ඕනෑම තැනක';

  @override
  String get noDefinitionsFound => 'අර්ථ දැක්වීම් හමු නොවීය';

  @override
  String get dictionaryLookup => 'ශබ්දකෝෂය';

  @override
  String get errorLoadingDefinitions => 'අර්ථ දැක්වීම් පූරණය කිරීමේ දෝෂයකි';
}
