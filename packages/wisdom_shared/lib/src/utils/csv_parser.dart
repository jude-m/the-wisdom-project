/// Parses a comma-separated string into a Set<String>.
///
/// Returns empty set for null or empty input.
/// Filters out empty segments from trailing commas.
Set<String> parseCsvToSet(String? csv) {
  if (csv == null || csv.isEmpty) return {};
  return csv.split(',').where((s) => s.isNotEmpty).toSet();
}
