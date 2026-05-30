import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/key_value_store.dart';
import '../../core/storage/key_value_store_provider.dart';
import '../../core/storage/storage_keys.dart';
import '../../domain/entities/content/content_language.dart';
import '../../domain/entities/content/edition.dart';
import '../../domain/entities/content/editions.dart';

/// The active edition. Hardcoded to BJT for Phase 1; a real edition picker can
/// override this later without touching the Content Language plumbing.
final currentEditionProvider = Provider<Edition>((ref) => bjtEdition);

/// Content Language options offered by the active edition, in declared order.
/// BJT → [pali, sinhala]. Future editions (e.g. SuttaCentral) → [pali, english].
final availableContentLanguagesProvider =
    Provider<List<ContentLanguage>>((ref) {
  final edition = ref.watch(currentEditionProvider);
  return edition.availableLanguages
      .map(ContentLanguage.fromIso)
      .whereType<ContentLanguage>()
      .toList(growable: false);
});

/// The raw saved Content Language preference. It may be a value the active
/// edition doesn't offer — always read [effectiveContentLanguageProvider] for
/// anything user-facing.
final contentLanguageProvider =
    StateNotifierProvider<ContentLanguageNotifier, ContentLanguage>((ref) {
  return ContentLanguageNotifier(ref.watch(keyValueStoreProvider));
});

/// The Content Language widgets should actually use: the saved choice clamped
/// to what the active edition supports, else the edition default (first
/// available). This is the "global + validated" behaviour.
final effectiveContentLanguageProvider = Provider<ContentLanguage>((ref) {
  final available = ref.watch(availableContentLanguagesProvider);
  final chosen = ref.watch(contentLanguageProvider);
  if (available.contains(chosen)) return chosen;
  return available.isEmpty ? ContentLanguage.sinhala : available.first;
});

/// Manages the Content Language preference with persistence.
///
/// Replaces the former `NavigationLanguageNotifier`. Loads synchronously in its
/// constructor (the [KeyValueStore] is ready by the time providers build).
class ContentLanguageNotifier extends StateNotifier<ContentLanguage> {
  ContentLanguageNotifier(this._store) : super(_loadInitial(_store));

  final KeyValueStore _store;

  static ContentLanguage _loadInitial(KeyValueStore store) {
    final raw = store.getString(StorageKeys.contentLanguage);
    return _parse(raw) ?? ContentLanguage.sinhala;
  }

  // `asNameMap()[value]` returns null for both a null and an unknown key.
  static ContentLanguage? _parse(String? value) =>
      ContentLanguage.values.asNameMap()[value];

  /// Updates the preference and persists it under the new key.
  ///
  /// Persistence is best-effort: [state] already changed, so the UI reflects
  /// the new language even if the write fails (e.g. storage quota on web). We
  /// swallow + log rather than let a rejected Future escape as an unhandled
  /// async error — call sites (the settings menu) don't await this.
  Future<void> setLanguage(ContentLanguage language) async {
    if (state == language) return;
    state = language;
    try {
      await _store.setString(StorageKeys.contentLanguage, language.name);
    } catch (e) {
      debugPrint('Failed to save content language: $e');
    }
  }
}
