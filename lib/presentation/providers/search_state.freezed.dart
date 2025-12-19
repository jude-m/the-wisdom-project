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
  SearchCategory get selectedCategory => throw _privateConstructorUsedError;

  /// Categorized results for "All" tab (grouped by category)
  CategorizedSearchResult? get categorizedResults =>
      throw _privateConstructorUsedError;

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
      SearchCategory selectedCategory,
      CategorizedSearchResult? categorizedResults,
      AsyncValue<List<SearchResult>> fullResults,
      bool isLoading,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool isPanelDismissed});

  $CategorizedSearchResultCopyWith<$Res>? get categorizedResults;
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
    Object? selectedCategory = null,
    Object? categorizedResults = freezed,
    Object? fullResults = null,
    Object? isLoading = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? isPanelDismissed = null,
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
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as SearchCategory,
      categorizedResults: freezed == categorizedResults
          ? _value.categorizedResults
          : categorizedResults // ignore: cast_nullable_to_non_nullable
              as CategorizedSearchResult?,
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
    ) as $Val);
  }

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CategorizedSearchResultCopyWith<$Res>? get categorizedResults {
    if (_value.categorizedResults == null) {
      return null;
    }

    return $CategorizedSearchResultCopyWith<$Res>(_value.categorizedResults!,
        (value) {
      return _then(_value.copyWith(categorizedResults: value) as $Val);
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
      SearchCategory selectedCategory,
      CategorizedSearchResult? categorizedResults,
      AsyncValue<List<SearchResult>> fullResults,
      bool isLoading,
      Set<String> selectedEditions,
      bool searchInPali,
      bool searchInSinhala,
      List<String> nikayaFilters,
      bool filtersVisible,
      bool isPanelDismissed});

  @override
  $CategorizedSearchResultCopyWith<$Res>? get categorizedResults;
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
    Object? selectedCategory = null,
    Object? categorizedResults = freezed,
    Object? fullResults = null,
    Object? isLoading = null,
    Object? selectedEditions = null,
    Object? searchInPali = null,
    Object? searchInSinhala = null,
    Object? nikayaFilters = null,
    Object? filtersVisible = null,
    Object? isPanelDismissed = null,
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
      selectedCategory: null == selectedCategory
          ? _value.selectedCategory
          : selectedCategory // ignore: cast_nullable_to_non_nullable
              as SearchCategory,
      categorizedResults: freezed == categorizedResults
          ? _value.categorizedResults
          : categorizedResults // ignore: cast_nullable_to_non_nullable
              as CategorizedSearchResult?,
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
    ));
  }
}

/// @nodoc

class _$SearchStateImpl extends _SearchState {
  const _$SearchStateImpl(
      {this.queryText = '',
      final List<RecentSearch> recentSearches = const [],
      this.selectedCategory = SearchCategory.all,
      this.categorizedResults,
      this.fullResults = const AsyncValue.data([]),
      this.isLoading = false,
      final Set<String> selectedEditions = const {},
      this.searchInPali = true,
      this.searchInSinhala = true,
      final List<String> nikayaFilters = const [],
      this.filtersVisible = false,
      this.isPanelDismissed = false})
      : _recentSearches = recentSearches,
        _selectedEditions = selectedEditions,
        _nikayaFilters = nikayaFilters,
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
  final SearchCategory selectedCategory;

  /// Categorized results for "All" tab (grouped by category)
  @override
  final CategorizedSearchResult? categorizedResults;

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

  @override
  String toString() {
    return 'SearchState(queryText: $queryText, recentSearches: $recentSearches, selectedCategory: $selectedCategory, categorizedResults: $categorizedResults, fullResults: $fullResults, isLoading: $isLoading, selectedEditions: $selectedEditions, searchInPali: $searchInPali, searchInSinhala: $searchInSinhala, nikayaFilters: $nikayaFilters, filtersVisible: $filtersVisible, isPanelDismissed: $isPanelDismissed)';
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
            (identical(other.selectedCategory, selectedCategory) ||
                other.selectedCategory == selectedCategory) &&
            (identical(other.categorizedResults, categorizedResults) ||
                other.categorizedResults == categorizedResults) &&
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
                other.isPanelDismissed == isPanelDismissed));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      queryText,
      const DeepCollectionEquality().hash(_recentSearches),
      selectedCategory,
      categorizedResults,
      fullResults,
      isLoading,
      const DeepCollectionEquality().hash(_selectedEditions),
      searchInPali,
      searchInSinhala,
      const DeepCollectionEquality().hash(_nikayaFilters),
      filtersVisible,
      isPanelDismissed);

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
      final SearchCategory selectedCategory,
      final CategorizedSearchResult? categorizedResults,
      final AsyncValue<List<SearchResult>> fullResults,
      final bool isLoading,
      final Set<String> selectedEditions,
      final bool searchInPali,
      final bool searchInSinhala,
      final List<String> nikayaFilters,
      final bool filtersVisible,
      final bool isPanelDismissed}) = _$SearchStateImpl;
  const _SearchState._() : super._();

  /// Current search query text
  @override
  String get queryText;

  /// Recent search history
  @override
  List<RecentSearch> get recentSearches;

  /// Currently selected category in results view
  @override
  SearchCategory get selectedCategory;

  /// Categorized results for "All" tab (grouped by category)
  @override
  CategorizedSearchResult? get categorizedResults;

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

  /// Create a copy of SearchState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchStateImplCopyWith<_$SearchStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
