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

  /// Current search mode (idle, recentSearches, previewResults, fullResults)
  SearchMode get mode => throw _privateConstructorUsedError;

  /// Recent search history
  List<RecentSearch> get recentSearches => throw _privateConstructorUsedError;

  /// Categorized preview results (for dropdown, max 3 per category)
  CategorizedSearchResult? get previewResults =>
      throw _privateConstructorUsedError;

  /// Whether preview is loading
  bool get isPreviewLoading => throw _privateConstructorUsedError;

  /// Currently selected category in full results view
  SearchCategory get selectedCategory => throw _privateConstructorUsedError;

  /// Full results for the selected category (async state)
  AsyncValue<List<SearchResult>> get fullResults =>
      throw _privateConstructorUsedError;

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

  /// Whether the current query was submitted (user pressed Enter)
  /// Used to determine if we should reopen the full results panel on focus
  bool get wasQuerySubmitted => throw _privateConstructorUsedError;

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
      SearchMode mode,
      List<RecentSearch> recentSearches,
      CategorizedSearchResult? previewResults,
      bool isPreviewLoading,
      SearchCategory selectedCategory,
      AsyncValue<List<SearchResult>> fullResults,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool wasQuerySubmitted});

  $CategorizedSearchResultCopyWith<$Res>? get previewResults;
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
    Object? mode = null,
    Object? recentSearches = null,
    Object? previewResults = freezed,
    Object? isPreviewLoading = null,
    Object? selectedCategory = null,
    Object? fullResults = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? wasQuerySubmitted = null,
  }) {
    return _then(_value.copyWith(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as SearchMode,
      recentSearches: null == recentSearches
          ? _value.recentSearches
          : recentSearches // ignore: cast_nullable_to_non_nullable
              as List<RecentSearch>,
      previewResults: freezed == previewResults
          ? _value.previewResults
          : previewResults // ignore: cast_nullable_to_non_nullable
              as CategorizedSearchResult?,
      isPreviewLoading: null == isPreviewLoading
          ? _value.isPreviewLoading
          : isPreviewLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as SearchCategory,
      fullResults: null == fullResults
          ? _value.fullResults
          : fullResults // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<SearchResult>>,
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
      wasQuerySubmitted: null == wasQuerySubmitted
          ? _value.wasQuerySubmitted
          : wasQuerySubmitted // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategorizedSearchResultCopyWith<$Res>? get previewResults {
    if (_value.previewResults == null) {
      return null;
    }

    return $CategorizedSearchResultCopyWith<$Res>(_value.previewResults!,
        (value) {
      return _then(_value.copyWith(previewResults: value) as $Val);
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
      SearchMode mode,
      List<RecentSearch> recentSearches,
      CategorizedSearchResult? previewResults,
      bool isPreviewLoading,
      SearchCategory selectedCategory,
      AsyncValue<List<SearchResult>> fullResults,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool wasQuerySubmitted});

  @override
  $CategorizedSearchResultCopyWith<$Res>? get previewResults;
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
    Object? mode = null,
    Object? recentSearches = null,
    Object? previewResults = freezed,
    Object? isPreviewLoading = null,
    Object? selectedCategory = null,
    Object? fullResults = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? wasQuerySubmitted = null,
  }) {
    return _then(_$SearchStateImpl(
      queryText: null == queryText
          ? _value.queryText
          : queryText // ignore: cast_nullable_to_non_nullable
              as String,
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as SearchMode,
      recentSearches: null == recentSearches
          ? _value._recentSearches
          : recentSearches // ignore: cast_nullable_to_non_nullable
              as List<RecentSearch>,
      previewResults: freezed == previewResults
          ? _value.previewResults
          : previewResults // ignore: cast_nullable_to_non_nullable
              as CategorizedSearchResult?,
      isPreviewLoading: null == isPreviewLoading
          ? _value.isPreviewLoading
          : isPreviewLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as SearchCategory,
      fullResults: null == fullResults
          ? _value.fullResults
          : fullResults // ignore: cast_nullable_to_non_nullable
              as AsyncValue<List<SearchResult>>,
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
      wasQuerySubmitted: null == wasQuerySubmitted
          ? _value.wasQuerySubmitted
          : wasQuerySubmitted // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$SearchStateImpl implements _SearchState {
  const _$SearchStateImpl(
      {this.queryText = '',
      this.mode = SearchMode.idle,
      final List<RecentSearch> recentSearches = const [],
      this.previewResults,
      this.isPreviewLoading = false,
      this.selectedCategory = SearchCategory.title,
      this.fullResults = const AsyncValue.data([]),
      final Set<String> selectedEditions = const {},
      this.searchInPali = true,
      this.searchInSinhala = true,
      final List<String> nikayaFilters = const [],
      this.filtersVisible = false,
      this.wasQuerySubmitted = false})
      : _recentSearches = recentSearches,
        _selectedEditions = selectedEditions,
        _nikayaFilters = nikayaFilters;

  /// Current search query text
  @override
  @JsonKey()
  final String queryText;

  /// Current search mode (idle, recentSearches, previewResults, fullResults)
  @override
  @JsonKey()
  final SearchMode mode;

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

  /// Categorized preview results (for dropdown, max 3 per category)
  @override
  final CategorizedSearchResult? previewResults;

  /// Whether preview is loading
  @override
  @JsonKey()
  final bool isPreviewLoading;

  /// Currently selected category in full results view
  @override
  @JsonKey()
  final SearchCategory selectedCategory;

  /// Full results for the selected category (async state)
  @override
  @JsonKey()
  final AsyncValue<List<SearchResult>> fullResults;

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

  /// Whether the current query was submitted (user pressed Enter)
  /// Used to determine if we should reopen the full results panel on focus
  @override
  @JsonKey()
  final bool wasQuerySubmitted;

  @override
  String toString() {
    return 'SearchState(queryText: $queryText, mode: $mode, recentSearches: $recentSearches, previewResults: $previewResults, isPreviewLoading: $isPreviewLoading, selectedCategory: $selectedCategory, fullResults: $fullResults, selectedEditions: $selectedEditions, searchInPali: $searchInPali, searchInSinhala: $searchInSinhala, nikayaFilters: $nikayaFilters, filtersVisible: $filtersVisible, wasQuerySubmitted: $wasQuerySubmitted)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchStateImpl &&
            (identical(other.queryText, queryText) ||
                other.queryText == queryText) &&
            (identical(other.mode, mode) || other.mode == mode) &&
            const DeepCollectionEquality()
                .equals(other._recentSearches, _recentSearches) &&
            (identical(other.previewResults, previewResults) ||
                other.previewResults == previewResults) &&
            (identical(other.isPreviewLoading, isPreviewLoading) ||
                other.isPreviewLoading == isPreviewLoading) &&
            (identical(other.selectedCategory, selectedCategory) ||
                other.selectedCategory == selectedCategory) &&
            (identical(other.fullResults, fullResults) ||
                other.fullResults == fullResults) &&
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
            (identical(other.wasQuerySubmitted, wasQuerySubmitted) ||
                other.wasQuerySubmitted == wasQuerySubmitted));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      queryText,
      mode,
      const DeepCollectionEquality().hash(_recentSearches),
      previewResults,
      isPreviewLoading,
      selectedCategory,
      fullResults,
      const DeepCollectionEquality().hash(_selectedEditions),
      searchInPali,
      searchInSinhala,
      const DeepCollectionEquality().hash(_nikayaFilters),
      filtersVisible,
      wasQuerySubmitted);

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      __$$SearchStateImplCopyWithImpl<_$SearchStateImpl>(this, _$identity);
}

abstract class _SearchState implements SearchState {
  const factory _SearchState(
      {final String queryText,
      final SearchMode mode,
      final List<RecentSearch> recentSearches,
      final CategorizedSearchResult? previewResults,
      final bool isPreviewLoading,
      final SearchCategory selectedCategory,
      final AsyncValue<List<SearchResult>> fullResults,
      final Set<String> selectedEditions,
      final bool searchInPali,
      final bool searchInSinhala,
      final List<String> nikayaFilters,
      final bool filtersVisible,
      final bool wasQuerySubmitted}) = _$SearchStateImpl;

  /// Current search query text
  @override
  String get queryText;

  /// Current search mode (idle, recentSearches, previewResults, fullResults)
  @override
  SearchMode get mode;

  /// Recent search history
  @override
  List<RecentSearch> get recentSearches;

  /// Categorized preview results (for dropdown, max 3 per category)
  @override
  CategorizedSearchResult? get previewResults;

  /// Whether preview is loading
  @override
  bool get isPreviewLoading;

  /// Currently selected category in full results view
  @override
  SearchCategory get selectedCategory;

  /// Full results for the selected category (async state)
  @override
  AsyncValue<List<SearchResult>> get fullResults;

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

  /// Whether the current query was submitted (user pressed Enter)
  /// Used to determine if we should reopen the full results panel on focus
  @override
  bool get wasQuerySubmitted;

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
