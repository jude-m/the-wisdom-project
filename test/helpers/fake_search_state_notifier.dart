import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_wisdom_project/domain/entities/search/search_result_type.dart';
import 'package:the_wisdom_project/presentation/providers/search_state.dart';

/// A [SearchStateNotifier] that holds any [SearchState] and runs no searches.
/// The setters widgets call apply straight to the state; anything else throws,
/// naming the missing member.
class FakeSearchStateNotifier extends StateNotifier<SearchState>
    implements SearchStateNotifier {
  FakeSearchStateNotifier(super.state);

  @override
  Future<void> selectResultType(SearchResultType resultType) async {
    state = state.copyWith(selectedResultType: resultType);
  }

  @override
  void setLanguageFilter({bool? pali, bool? sinhala}) {
    state = state.copyWith(
      searchInPali: pali ?? state.searchInPali,
      searchInSinhala: sinhala ?? state.searchInSinhala,
    );
  }

  @override
  void setScope(Set<String> nodeKeys) =>
      state = state.copyWith(scope: nodeKeys);

  @override
  void toggleFTSGroupExpansion(String nodeKey) {
    final groups = state.expandedFTSGroups;
    state = state.copyWith(
      expandedFTSGroups: groups.contains(nodeKey)
          ? ({...groups}..remove(nodeKey))
          : {...groups, nodeKey},
    );
  }

  @override
  void setMatchOptions({
    bool? isExactMatch,
    bool? isPhraseSearch,
    bool? isAnywhereInText,
    int? proximityDistance,
  }) {
    state = state.copyWith(
      isExactMatch: isExactMatch ?? state.isExactMatch,
      isPhraseSearch: isPhraseSearch ?? state.isPhraseSearch,
      isAnywhereInText: isAnywhereInText ?? state.isAnywhereInText,
      proximityDistance: proximityDistance ?? state.proximityDistance,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'FakeSearchStateNotifier does not implement '
      '${invocation.memberName} — add it to the fake if your test needs it.',
    );
  }
}
