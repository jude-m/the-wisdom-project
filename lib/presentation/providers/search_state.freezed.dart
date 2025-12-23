// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SearchState {
  /// Current search query text
  String get queryText => throw _privateConstructorUsedError;

  /// Recent search history
  List<RecentSearch> get recentSearches => throw _privateConstructorUsedError;

  /// Currently selected category in results view
  SearchResultType get selectedResultType => throw _privateConstructorUsedError;

  /// Categorized results for "Top Results" tab (grouped by category)
  GroupedSearchResult? get groupedResults => throw _privateConstructorUsedError;

  /// Full results for the selected category (async state)
  AsyncValue<List<SearchResult>> get fullResults =>
      throw _privateConstructorUsedError;

  /// Whether results are currently loading
  bool get isLoading => throw _privateConstructorUsedError;

  /// Selected editions to search (empty = default to BJT)
  Set<String> get selectedEditions => throw _privateConstructorUsedError;

  /// Whether to search in Pali text
  bool get searchInPali => throw _privateConstructorUsedError;

  /// Whether to search in Sinhala text
  bool get searchInSinhala => throw _privateConstructorUsedError;

  /// Nikaya filters (e.g., ['dn', 'mn'])
  List<String> get nikayaFilters => throw _privateConstructorUsedError;

  /// Whether the filter panel is visible
  bool get filtersVisible => throw _privateConstructorUsedError;

  /// Whether the panel was dismissed (user clicked result or close button)
  /// Panel reopens when user focuses the search bar again
  bool get isPanelDismissed => throw _privateConstructorUsedError;

  /// Whether exact match is enabled (default: false = prefix matching)
  /// When false: "සති" matches "සතිපට්ඨානය", "සතිපට්ඨාන", etc.
  /// When true: "සති" matches only "සති" exactly
  bool get isExactMatch => throw _privateConstructorUsedError;

  /// Result counts per category (for tab badges)
  /// Updated independently from categorized results
  Map<SearchResultType, int> get countByResultType =>
      throw _privateConstructorUsedError;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchStateCopyWith<SearchState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchStateCopyWith<$Res> {
  factory $SearchStateCopyWith(
          SearchState value, $Res Function(SearchState) then) =
      _$SearchStateCopyWithImpl<$Res, SearchState>;
  @useResult
  $Res call(
      {String queryText,
      List<RecentSearch> recentSearches,
      SearchResultType selectedResultType,
      GroupedSearchResult? groupedResults,
      AsyncValue<List<SearchResult>> fullResults,
      bool isLoading,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool isPanelDismissed,
      bool isExactMatch,
      Map<SearchResultType, int> countByResultType});

  $GroupedSearchResultCopyWith<$Res>? get groupedResults;
}

/// @nodoc
class _$SearchStateCopyWithImpl<$Res, $Val extends SearchState>
    implements $SearchStateCopyWith<$Res> {
  _$SearchStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? recentSearches = null,
    Object? selectedResultType = null,
    Object? groupedResults = freezed,
    Object? fullResults = null,
    Object? isLoading = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? isPanelDismissed = null,
    Object? isExactMatch = null,
    Object? countByResultType = null,
  }) {
    return _then(_value.copyWith(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      recentSearches: null == recentSearches
          ? _value.recentSearches
          : recentSearches // ignore: cast_nullable_to_non_nullable
              as List<RecentSearch>,
      selectedResultType: null == selectedResultType
          ? _value.selectedResultType
          : selectedResultType // ignore: cast_nullable_to_non_nullable
              as SearchResultType,
      groupedResults: freezed == groupedResults
          ? _value.groupedResults
          : groupedResults // ignore: cast_nullable_to_non_nullable
              as GroupedSearchResult?,
      fullResults: null == fullResults
          ? _value.fullResults
          : fullResults // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<SearchResult>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedEditions: null == selectedEditions
          ? _value.selectedEditions
          : selectedEditions // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      searchInPali: null == searchInPali
          ? _value.searchInPali
          : searchInPali // ignore: cast_nullable_to_non_nullable
              as bool,
      searchInSinhala: null == searchInSinhala
          ? _value.searchInSinhala
          : searchInSinhala // ignore: cast_nullable_to_non_nullable
              as bool,
      nikayaFilters: null == nikayaFilters
          ? _value.nikayaFilters
          : nikayaFilters // ignore: cast_nullable_to_non_nullable
              as List<String>,
      filtersVisible: null == filtersVisible
          ? _value.filtersVisible
          : filtersVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isPanelDismissed: null == isPanelDismissed
          ? _value.isPanelDismissed
          : isPanelDismissed // ignore: cast_nullable_to_non_nullable
              as bool,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      countByResultType: null == countByResultType
          ? _value.countByResultType
          : countByResultType // ignore: cast_nullable_to_non_nullable
              as Map<SearchResultType, int>,
    ) as $Val);
  }

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $GroupedSearchResultCopyWith<$Res>? get groupedResults {
    if (_value.groupedResults == null) {
      return null;
    }

    return $GroupedSearchResultCopyWith<$Res>(_value.groupedResults!, (value) {
      return _then(_value.copyWith(groupedResults: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SearchStateImplCopyWith<$Res>
    implements $SearchStateCopyWith<$Res> {
  factory _$$SearchStateImplCopyWith(
          _$SearchStateImpl value, $Res Function(_$SearchStateImpl) then) =
      __$$SearchStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String queryText,
      List<RecentSearch> recentSearches,
      SearchResultType selectedResultType,
      GroupedSearchResult? groupedResults,
      AsyncValue<List<SearchResult>> fullResults,
      bool isLoading,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool isPanelDismissed,
      bool isExactMatch,
      Map<SearchResultType, int> countByResultType});

  @override
  $GroupedSearchResultCopyWith<$Res>? get groupedResults;
}

/// @nodoc
class __$$SearchStateImplCopyWithImpl<$Res>
    extends _$SearchStateCopyWithImpl<$Res, _$SearchStateImpl>
    implements _$$SearchStateImplCopyWith<$Res> {
  __$$SearchStateImplCopyWithImpl(
      _$SearchStateImpl _value, $Res Function(_$SearchStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? queryText = null,
    Object? recentSearches = null,
    Object? selectedResultType = null,
    Object? groupedResults = freezed,
    Object? fullResults = null,
    Object? isLoading = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? isPanelDismissed = null,
    Object? isExactMatch = null,
    Object? countByResultType = null,
  }) {
    return _then(_$SearchStateImpl(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      recentSearches: null == recentSearches
          ? _value._recentSearches
          : recentSearches // ignore: cast_nullable_to_non_nullable
              as List<RecentSearch>,
      selectedResultType: null == selectedResultType
          ? _value.selectedResultType
          : selectedResultType // ignore: cast_nullable_to_non_nullable
              as SearchResultType,
      groupedResults: freezed == groupedResults
          ? _value.groupedResults
          : groupedResults // ignore: cast_nullable_to_non_nullable
              as GroupedSearchResult?,
      fullResults: null == fullResults
          ? _value.fullResults
          : fullResults // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<SearchResult>>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedEditions: null == selectedEditions
          ? _value._selectedEditions
          : selectedEditions // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      searchInPali: null == searchInPali
          ? _value.searchInPali
          : searchInPali // ignore: cast_nullable_to_non_nullable
              as bool,
      searchInSinhala: null == searchInSinhala
          ? _value.searchInSinhala
          : searchInSinhala // ignore: cast_nullable_to_non_nullable
              as bool,
      nikayaFilters: null == nikayaFilters
          ? _value._nikayaFilters
          : nikayaFilters // ignore: cast_nullable_to_non_nullable
              as List<String>,
      filtersVisible: null == filtersVisible
          ? _value.filtersVisible
          : filtersVisible // ignore: cast_nullable_to_non_nullable
              as bool,
      isPanelDismissed: null == isPanelDismissed
          ? _value.isPanelDismissed
          : isPanelDismissed // ignore: cast_nullable_to_non_nullable
              as bool,
      isExactMatch: null == isExactMatch
          ? _value.isExactMatch
          : isExactMatch // ignore: cast_nullable_to_non_nullable
              as bool,
      countByResultType: null == countByResultType
          ? _value._countByResultType
          : countByResultType // ignore: cast_nullable_to_non_nullable
              as Map<SearchResultType, int>,
    ));
  }
}

/// @nodoc

class _$SearchStateImpl extends _SearchState {
  const _$SearchStateImpl(
      {this.queryText = '',
      final List<RecentSearch> recentSearches = const [],
      this.selectedResultType = SearchResultType.topResults,
      this.groupedResults,
      this.fullResults = const AsyncValue.data([]),
      this.isLoading = false,
      final Set<String> selectedEditions = const {},
      this.searchInPali = true,
      this.searchInSinhala = true,
      final List<String> nikayaFilters = const [],
      this.filtersVisible = false,
      this.isPanelDismissed = false,
      this.isExactMatch = false,
      final Map<SearchResultType, int> countByResultType = const {}})
      : _recentSearches = recentSearches,
        _selectedEditions = selectedEditions,
        _nikayaFilters = nikayaFilters,
        _countByResultType = countByResultType,
        super._();

  /// Current search query text
  @override
  @JsonKey()
  final String queryText;

  /// Recent search history
  final List<RecentSearch> _recentSearches;

  /// Recent search history
  @override
  @JsonKey()
  List<RecentSearch> get recentSearches {
    if (_recentSearches is EqualUnmodifiableListView) return _recentSearches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_recentSearches);
  }

  /// Currently selected category in results view
  @override
  @JsonKey()
  final SearchResultType selectedResultType;

  /// Categorized results for "Top Results" tab (grouped by category)
  @override
  final GroupedSearchResult? groupedResults;

  /// Full results for the selected category (async state)
  @override
  @JsonKey()
  final AsyncValue<List<SearchResult>> fullResults;

  /// Whether results are currently loading
  @override
  @JsonKey()
  final bool isLoading;

  /// Selected editions to search (empty = default to BJT)
  final Set<String> _selectedEditions;

  /// Selected editions to search (empty = default to BJT)
  @override
  @JsonKey()
  Set<String> get selectedEditions {
    if (_selectedEditions is EqualUnmodifiableSetView) return _selectedEditions;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_selectedEditions);
  }

  /// Whether to search in Pali text
  @override
  @JsonKey()
  final bool searchInPali;

  /// Whether to search in Sinhala text
  @override
  @JsonKey()
  final bool searchInSinhala;

  /// Nikaya filters (e.g., ['dn', 'mn'])
  final List<String> _nikayaFilters;

  /// Nikaya filters (e.g., ['dn', 'mn'])
  @override
  @JsonKey()
  List<String> get nikayaFilters {
    if (_nikayaFilters is EqualUnmodifiableListView) return _nikayaFilters;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_nikayaFilters);
  }

  /// Whether the filter panel is visible
  @override
  @JsonKey()
  final bool filtersVisible;

  /// Whether the panel was dismissed (user clicked result or close button)
  /// Panel reopens when user focuses the search bar again
  @override
  @JsonKey()
  final bool isPanelDismissed;

  /// Whether exact match is enabled (default: false = prefix matching)
  /// When false: "සති" matches "සතිපට්ඨානය", "සතිපට්ඨාන", etc.
  /// When true: "සති" matches only "සති" exactly
  @override
  @JsonKey()
  final bool isExactMatch;

  /// Result counts per category (for tab badges)
  /// Updated independently from categorized results
  final Map<SearchResultType, int> _countByResultType;

  /// Result counts per category (for tab badges)
  /// Updated independently from categorized results
  @override
  @JsonKey()
  Map<SearchResultType, int> get countByResultType {
    if (_countByResultType is EqualUnmodifiableMapView)
      return _countByResultType;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_countByResultType);
  }

  @override
  String toString() {
    return 'SearchState(queryText: $queryText, recentSearches: $recentSearches, selectedResultType: $selectedResultType, groupedResults: $groupedResults, fullResults: $fullResults, isLoading: $isLoading, selectedEditions: $selectedEditions, searchInPali: $searchInPali, searchInSinhala: $searchInSinhala, nikayaFilters: $nikayaFilters, filtersVisible: $filtersVisible, isPanelDismissed: $isPanelDismissed, isExactMatch: $isExactMatch, countByResultType: $countByResultType)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchStateImpl &&
            (identical(other.queryText, queryText) ||
                other.queryText == queryText) &&
            const DeepCollectionEquality()
                .equals(other._recentSearches, _recentSearches) &&
            (identical(other.selectedResultType, selectedResultType) ||
                other.selectedResultType == selectedResultType) &&
            (identical(other.groupedResults, groupedResults) ||
                other.groupedResults == groupedResults) &&
            (identical(other.fullResults, fullResults) ||
                other.fullResults == fullResults) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            const DeepCollectionEquality()
                .equals(other._selectedEditions, _selectedEditions) &&
            (identical(other.searchInPali, searchInPali) ||
                other.searchInPali == searchInPali) &&
            (identical(other.searchInSinhala, searchInSinhala) ||
                other.searchInSinhala == searchInSinhala) &&
            const DeepCollectionEquality()
                .equals(other._nikayaFilters, _nikayaFilters) &&
            (identical(other.filtersVisible, filtersVisible) ||
                other.filtersVisible == filtersVisible) &&
            (identical(other.isPanelDismissed, isPanelDismissed) ||
                other.isPanelDismissed == isPanelDismissed) &&
            (identical(other.isExactMatch, isExactMatch) ||
                other.isExactMatch == isExactMatch) &&
            const DeepCollectionEquality()
                .equals(other._countByResultType, _countByResultType));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      queryText,
      const DeepCollectionEquality().hash(_recentSearches),
      selectedResultType,
      groupedResults,
      fullResults,
      isLoading,
      const DeepCollectionEquality().hash(_selectedEditions),
      searchInPali,
      searchInSinhala,
      const DeepCollectionEquality().hash(_nikayaFilters),
      filtersVisible,
      isPanelDismissed,
      isExactMatch,
      const DeepCollectionEquality().hash(_countByResultType));

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      __$$SearchStateImplCopyWithImpl<_$SearchStateImpl>(this, _$identity);
}

abstract class _SearchState extends SearchState {
  const factory _SearchState(
      {final String queryText,
      final List<RecentSearch> recentSearches,
      final SearchResultType selectedResultType,
      final GroupedSearchResult? groupedResults,
      final AsyncValue<List<SearchResult>> fullResults,
      final bool isLoading,
      final Set<String> selectedEditions,
      final bool searchInPali,
      final bool searchInSinhala,
      final List<String> nikayaFilters,
      final bool filtersVisible,
      final bool isPanelDismissed,
      final bool isExactMatch,
      final Map<SearchResultType, int> countByResultType}) = _$SearchStateImpl;
  const _SearchState._() : super._();

  /// Current search query text
  @override
  String get queryText;

  /// Recent search history
  @override
  List<RecentSearch> get recentSearches;

  /// Currently selected category in results view
  @override
  SearchResultType get selectedResultType;

  /// Categorized results for "Top Results" tab (grouped by category)
  @override
  GroupedSearchResult? get groupedResults;

  /// Full results for the selected category (async state)
  @override
  AsyncValue<List<SearchResult>> get fullResults;

  /// Whether results are currently loading
  @override
  bool get isLoading;

  /// Selected editions to search (empty = default to BJT)
  @override
  Set<String> get selectedEditions;

  /// Whether to search in Pali text
  @override
  bool get searchInPali;

  /// Whether to search in Sinhala text
  @override
  bool get searchInSinhala;

  /// Nikaya filters (e.g., ['dn', 'mn'])
  @override
  List<String> get nikayaFilters;

  /// Whether the filter panel is visible
  @override
  bool get filtersVisible;

  /// Whether the panel was dismissed (user clicked result or close button)
  /// Panel reopens when user focuses the search bar again
  @override
  bool get isPanelDismissed;

  /// Whether exact match is enabled (default: false = prefix matching)
  /// When false: "සති" matches "සතිපට්ඨානය", "සතිපට්ඨාන", etc.
  /// When true: "සති" matches only "සති" exactly
  @override
  bool get isExactMatch;

  /// Result counts per category (for tab badges)
  /// Updated independently from categorized results
  @override
  Map<SearchResultType, int> get countByResultType;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
