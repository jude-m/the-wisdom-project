// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$SearchResult {
  /// Unique identifier for this result
  String get id => throw _privateConstructorUsedError;

  /// Edition this result came from (e.g., 'bjt', 'sc')
  String get editionId => throw _privateConstructorUsedError;

  /// Category this result belongs to (title, content, or definition)
  SearchResultType get category => throw _privateConstructorUsedError;

  /// Title of the sutta/document
  String get title => throw _privateConstructorUsedError;

  /// Subtitle showing the navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  String get subtitle => throw _privateConstructorUsedError;

  /// The actual text that matched the search query
  String get matchedText => throw _privateConstructorUsedError;

  /// Text before the match (for context preview)
  String get contextBefore => throw _privateConstructorUsedError;

  /// Text after the match (for context preview)
  String get contextAfter => throw _privateConstructorUsedError;

  /// File ID for navigation (e.g., "dn-1")
  String get contentFileId => throw _privateConstructorUsedError;

  /// Page index where the match is located
  int get pageIndex => throw _privateConstructorUsedError;

  /// Entry index within the page
  int get entryIndex => throw _privateConstructorUsedError;

  /// Reference to the tree node
  String get nodeKey => throw _privateConstructorUsedError;

  /// Language of the matched text
  String get language => throw _privateConstructorUsedError;

  /// Relevance score for ranking (optional)
  double? get relevanceScore => throw _privateConstructorUsedError;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SearchResultCopyWith<SearchResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SearchResultCopyWith<$Res> {
  factory $SearchResultCopyWith(
          SearchResult value, $Res Function(SearchResult) then) =
      _$SearchResultCopyWithImpl<$Res, SearchResult>;
  @useResult
  $Res call(
      {String id,
      String editionId,
      SearchResultType category,
      String title,
      String subtitle,
      String matchedText,
      String contextBefore,
      String contextAfter,
      String contentFileId,
      int pageIndex,
      int entryIndex,
      String nodeKey,
      String language,
      double? relevanceScore});
}

/// @nodoc
class _$SearchResultCopyWithImpl<$Res, $Val extends SearchResult>
    implements $SearchResultCopyWith<$Res> {
  _$SearchResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? editionId = null,
    Object? category = null,
    Object? title = null,
    Object? subtitle = null,
    Object? matchedText = null,
    Object? contextBefore = null,
    Object? contextAfter = null,
    Object? contentFileId = null,
    Object? pageIndex = null,
    Object? entryIndex = null,
    Object? nodeKey = null,
    Object? language = null,
    Object? relevanceScore = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as SearchResultType,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      matchedText: null == matchedText
          ? _value.matchedText
          : matchedText // ignore: cast_nullable_to_non_nullable
              as String,
      contextBefore: null == contextBefore
          ? _value.contextBefore
          : contextBefore // ignore: cast_nullable_to_non_nullable
              as String,
      contextAfter: null == contextAfter
          ? _value.contextAfter
          : contextAfter // ignore: cast_nullable_to_non_nullable
              as String,
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      pageIndex: null == pageIndex
          ? _value.pageIndex
          : pageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      entryIndex: null == entryIndex
          ? _value.entryIndex
          : entryIndex // ignore: cast_nullable_to_non_nullable
              as int,
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      relevanceScore: freezed == relevanceScore
          ? _value.relevanceScore
          : relevanceScore // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SearchResultImplCopyWith<$Res>
    implements $SearchResultCopyWith<$Res> {
  factory _$$SearchResultImplCopyWith(
          _$SearchResultImpl value, $Res Function(_$SearchResultImpl) then) =
      __$$SearchResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String editionId,
      SearchResultType category,
      String title,
      String subtitle,
      String matchedText,
      String contextBefore,
      String contextAfter,
      String contentFileId,
      int pageIndex,
      int entryIndex,
      String nodeKey,
      String language,
      double? relevanceScore});
}

/// @nodoc
class __$$SearchResultImplCopyWithImpl<$Res>
    extends _$SearchResultCopyWithImpl<$Res, _$SearchResultImpl>
    implements _$$SearchResultImplCopyWith<$Res> {
  __$$SearchResultImplCopyWithImpl(
      _$SearchResultImpl _value, $Res Function(_$SearchResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? editionId = null,
    Object? category = null,
    Object? title = null,
    Object? subtitle = null,
    Object? matchedText = null,
    Object? contextBefore = null,
    Object? contextAfter = null,
    Object? contentFileId = null,
    Object? pageIndex = null,
    Object? entryIndex = null,
    Object? nodeKey = null,
    Object? language = null,
    Object? relevanceScore = freezed,
  }) {
    return _then(_$SearchResultImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      category: null == category
          ? _value.category
          : category // ignore: cast_nullable_to_non_nullable
              as SearchResultType,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      matchedText: null == matchedText
          ? _value.matchedText
          : matchedText // ignore: cast_nullable_to_non_nullable
              as String,
      contextBefore: null == contextBefore
          ? _value.contextBefore
          : contextBefore // ignore: cast_nullable_to_non_nullable
              as String,
      contextAfter: null == contextAfter
          ? _value.contextAfter
          : contextAfter // ignore: cast_nullable_to_non_nullable
              as String,
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      pageIndex: null == pageIndex
          ? _value.pageIndex
          : pageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      entryIndex: null == entryIndex
          ? _value.entryIndex
          : entryIndex // ignore: cast_nullable_to_non_nullable
              as int,
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      language: null == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String,
      relevanceScore: freezed == relevanceScore
          ? _value.relevanceScore
          : relevanceScore // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc

class _$SearchResultImpl implements _SearchResult {
  const _$SearchResultImpl(
      {required this.id,
      required this.editionId,
      required this.category,
      required this.title,
      required this.subtitle,
      required this.matchedText,
      this.contextBefore = '',
      this.contextAfter = '',
      required this.contentFileId,
      required this.pageIndex,
      required this.entryIndex,
      required this.nodeKey,
      required this.language,
      this.relevanceScore});

  /// Unique identifier for this result
  @override
  final String id;

  /// Edition this result came from (e.g., 'bjt', 'sc')
  @override
  final String editionId;

  /// Category this result belongs to (title, content, or definition)
  @override
  final SearchResultType category;

  /// Title of the sutta/document
  @override
  final String title;

  /// Subtitle showing the navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  @override
  final String subtitle;

  /// The actual text that matched the search query
  @override
  final String matchedText;

  /// Text before the match (for context preview)
  @override
  @JsonKey()
  final String contextBefore;

  /// Text after the match (for context preview)
  @override
  @JsonKey()
  final String contextAfter;

  /// File ID for navigation (e.g., "dn-1")
  @override
  final String contentFileId;

  /// Page index where the match is located
  @override
  final int pageIndex;

  /// Entry index within the page
  @override
  final int entryIndex;

  /// Reference to the tree node
  @override
  final String nodeKey;

  /// Language of the matched text
  @override
  final String language;

  /// Relevance score for ranking (optional)
  @override
  final double? relevanceScore;

  @override
  String toString() {
    return 'SearchResult(id: $id, editionId: $editionId, category: $category, title: $title, subtitle: $subtitle, matchedText: $matchedText, contextBefore: $contextBefore, contextAfter: $contextAfter, contentFileId: $contentFileId, pageIndex: $pageIndex, entryIndex: $entryIndex, nodeKey: $nodeKey, language: $language, relevanceScore: $relevanceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SearchResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.editionId, editionId) ||
                other.editionId == editionId) &&
            (identical(other.category, category) ||
                other.category == category) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.matchedText, matchedText) ||
                other.matchedText == matchedText) &&
            (identical(other.contextBefore, contextBefore) ||
                other.contextBefore == contextBefore) &&
            (identical(other.contextAfter, contextAfter) ||
                other.contextAfter == contextAfter) &&
            (identical(other.contentFileId, contentFileId) ||
                other.contentFileId == contentFileId) &&
            (identical(other.pageIndex, pageIndex) ||
                other.pageIndex == pageIndex) &&
            (identical(other.entryIndex, entryIndex) ||
                other.entryIndex == entryIndex) &&
            (identical(other.nodeKey, nodeKey) || other.nodeKey == nodeKey) &&
            (identical(other.language, language) ||
                other.language == language) &&
            (identical(other.relevanceScore, relevanceScore) ||
                other.relevanceScore == relevanceScore));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      editionId,
      category,
      title,
      subtitle,
      matchedText,
      contextBefore,
      contextAfter,
      contentFileId,
      pageIndex,
      entryIndex,
      nodeKey,
      language,
      relevanceScore);

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      __$$SearchResultImplCopyWithImpl<_$SearchResultImpl>(this, _$identity);
}

abstract class _SearchResult implements SearchResult {
  const factory _SearchResult(
      {required final String id,
      required final String editionId,
      required final SearchResultType category,
      required final String title,
      required final String subtitle,
      required final String matchedText,
      final String contextBefore,
      final String contextAfter,
      required final String contentFileId,
      required final int pageIndex,
      required final int entryIndex,
      required final String nodeKey,
      required final String language,
      final double? relevanceScore}) = _$SearchResultImpl;

  /// Unique identifier for this result
  @override
  String get id;

  /// Edition this result came from (e.g., 'bjt', 'sc')
  @override
  String get editionId;

  /// Category this result belongs to (title, content, or definition)
  @override
  SearchResultType get category;

  /// Title of the sutta/document
  @override
  String get title;

  /// Subtitle showing the navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  @override
  String get subtitle;

  /// The actual text that matched the search query
  @override
  String get matchedText;

  /// Text before the match (for context preview)
  @override
  String get contextBefore;

  /// Text after the match (for context preview)
  @override
  String get contextAfter;

  /// File ID for navigation (e.g., "dn-1")
  @override
  String get contentFileId;

  /// Page index where the match is located
  @override
  int get pageIndex;

  /// Entry index within the page
  @override
  int get entryIndex;

  /// Reference to the tree node
  @override
  String get nodeKey;

  /// Language of the matched text
  @override
  String get language;

  /// Relevance score for ranking (optional)
  @override
  double? get relevanceScore;

  /// Create a copy of SearchResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SearchResultImplCopyWith<_$SearchResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
