/// Infers the target language of a dictionary entry from its dictionary ID.
///
/// BUS and MS are Sinhala-target dictionaries; all others target English.
String inferTargetLanguage(String dictionaryId) {
  return (dictionaryId == 'BUS' || dictionaryId == 'MS') ? 'si' : 'en';
}
