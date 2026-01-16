// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'grouped_fts_match.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GroupedFTSMatch {
  /// Content file identifier (e.g., 'dn-1') - the grouping key
  String get contentFileId => throw _privateConstructorUsedError;

  /// Tree navigation key
  String get nodeKey => throw _privateConstructorUsedError;

  /// Document title
  String get title => throw _privateConstructorUsedError;

  /// Navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  String get subtitle => throw _privateConstructorUsedError;

  /// Edition this group belongs to (e.g., 'bjt', 'sc')
  String get editionId => throw _privateConstructorUsedError;

  /// First match shown in collapsed view
  SearchResult get primaryMatch => throw _privateConstructorUsedError;

  /// Additional matches (shown when expanded)
  List<SearchResult> get secondaryMatches => throw _privateConstructorUsedError;

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GroupedFTSMatchCopyWith<GroupedFTSMatch> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GroupedFTSMatchCopyWith<$Res> {
  factory $GroupedFTSMatchCopyWith(
          GroupedFTSMatch value, $Res Function(GroupedFTSMatch) then) =
      _$GroupedFTSMatchCopyWithImpl<$Res, GroupedFTSMatch>;
  @useResult
  $Res call(
      {String contentFileId,
      String nodeKey,
      String title,
      String subtitle,
      String editionId,
      SearchResult primaryMatch,
      List<SearchResult> secondaryMatches});

  $SearchResultCopyWith<$Res> get primaryMatch;
}

/// @nodoc
class _$GroupedFTSMatchCopyWithImpl<$Res, $Val extends GroupedFTSMatch>
    implements $GroupedFTSMatchCopyWith<$Res> {
  _$GroupedFTSMatchCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentFileId = null,
    Object? nodeKey = null,
    Object? title = null,
    Object? subtitle = null,
    Object? editionId = null,
    Object? primaryMatch = null,
    Object? secondaryMatches = null,
  }) {
    return _then(_value.copyWith(
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      primaryMatch: null == primaryMatch
          ? _value.primaryMatch
          : primaryMatch // ignore: cast_nullable_to_non_nullable
              as SearchResult,
      secondaryMatches: null == secondaryMatches
          ? _value.secondaryMatches
          : secondaryMatches // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
    ) as $Val);
  }

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SearchResultCopyWith<$Res> get primaryMatch {
    return $SearchResultCopyWith<$Res>(_value.primaryMatch, (value) {
      return _then(_value.copyWith(primaryMatch: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$GroupedFTSMatchImplCopyWith<$Res>
    implements $GroupedFTSMatchCopyWith<$Res> {
  factory _$$GroupedFTSMatchImplCopyWith(_$GroupedFTSMatchImpl value,
          $Res Function(_$GroupedFTSMatchImpl) then) =
      __$$GroupedFTSMatchImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String contentFileId,
      String nodeKey,
      String title,
      String subtitle,
      String editionId,
      SearchResult primaryMatch,
      List<SearchResult> secondaryMatches});

  @override
  $SearchResultCopyWith<$Res> get primaryMatch;
}

/// @nodoc
class __$$GroupedFTSMatchImplCopyWithImpl<$Res>
    extends _$GroupedFTSMatchCopyWithImpl<$Res, _$GroupedFTSMatchImpl>
    implements _$$GroupedFTSMatchImplCopyWith<$Res> {
  __$$GroupedFTSMatchImplCopyWithImpl(
      _$GroupedFTSMatchImpl _value, $Res Function(_$GroupedFTSMatchImpl) _then)
      : super(_value, _then);

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentFileId = null,
    Object? nodeKey = null,
    Object? title = null,
    Object? subtitle = null,
    Object? editionId = null,
    Object? primaryMatch = null,
    Object? secondaryMatches = null,
  }) {
    return _then(_$GroupedFTSMatchImpl(
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _value.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      subtitle: null == subtitle
          ? _value.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      primaryMatch: null == primaryMatch
          ? _value.primaryMatch
          : primaryMatch // ignore: cast_nullable_to_non_nullable
              as SearchResult,
      secondaryMatches: null == secondaryMatches
          ? _value._secondaryMatches
          : secondaryMatches // ignore: cast_nullable_to_non_nullable
              as List<SearchResult>,
    ));
  }
}

/// @nodoc

class _$GroupedFTSMatchImpl extends _GroupedFTSMatch {
  const _$GroupedFTSMatchImpl(
      {required this.contentFileId,
      required this.nodeKey,
      required this.title,
      required this.subtitle,
      required this.editionId,
      required this.primaryMatch,
      final List<SearchResult> secondaryMatches = const []})
      : _secondaryMatches = secondaryMatches,
        super._();

  /// Content file identifier (e.g., 'dn-1') - the grouping key
  @override
  final String contentFileId;

  /// Tree navigation key
  @override
  final String nodeKey;

  /// Document title
  @override
  final String title;

  /// Navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  @override
  final String subtitle;

  /// Edition this group belongs to (e.g., 'bjt', 'sc')
  @override
  final String editionId;

  /// First match shown in collapsed view
  @override
  final SearchResult primaryMatch;

  /// Additional matches (shown when expanded)
  final List<SearchResult> _secondaryMatches;

  /// Additional matches (shown when expanded)
  @override
  @JsonKey()
  List<SearchResult> get secondaryMatches {
    if (_secondaryMatches is EqualUnmodifiableListView)
      return _secondaryMatches;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_secondaryMatches);
  }

  @override
  String toString() {
    return 'GroupedFTSMatch(contentFileId: $contentFileId, nodeKey: $nodeKey, title: $title, subtitle: $subtitle, editionId: $editionId, primaryMatch: $primaryMatch, secondaryMatches: $secondaryMatches)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GroupedFTSMatchImpl &&
            (identical(other.contentFileId, contentFileId) ||
                other.contentFileId == contentFileId) &&
            (identical(other.nodeKey, nodeKey) || other.nodeKey == nodeKey) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.editionId, editionId) ||
                other.editionId == editionId) &&
            (identical(other.primaryMatch, primaryMatch) ||
                other.primaryMatch == primaryMatch) &&
            const DeepCollectionEquality()
                .equals(other._secondaryMatches, _secondaryMatches));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      contentFileId,
      nodeKey,
      title,
      subtitle,
      editionId,
      primaryMatch,
      const DeepCollectionEquality().hash(_secondaryMatches));

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GroupedFTSMatchImplCopyWith<_$GroupedFTSMatchImpl> get copyWith =>
      __$$GroupedFTSMatchImplCopyWithImpl<_$GroupedFTSMatchImpl>(
          this, _$identity);
}

abstract class _GroupedFTSMatch extends GroupedFTSMatch {
  const factory _GroupedFTSMatch(
      {required final String contentFileId,
      required final String nodeKey,
      required final String title,
      required final String subtitle,
      required final String editionId,
      required final SearchResult primaryMatch,
      final List<SearchResult> secondaryMatches}) = _$GroupedFTSMatchImpl;
  const _GroupedFTSMatch._() : super._();

  /// Content file identifier (e.g., 'dn-1') - the grouping key
  @override
  String get contentFileId;

  /// Tree navigation key
  @override
  String get nodeKey;

  /// Document title
  @override
  String get title;

  /// Navigation path (e.g., "Dīgha Nikāya > Sīlakkhandhavagga")
  @override
  String get subtitle;

  /// Edition this group belongs to (e.g., 'bjt', 'sc')
  @override
  String get editionId;

  /// First match shown in collapsed view
  @override
  SearchResult get primaryMatch;

  /// Additional matches (shown when expanded)
  @override
  List<SearchResult> get secondaryMatches;

  /// Create a copy of GroupedFTSMatch
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GroupedFTSMatchImplCopyWith<_$GroupedFTSMatchImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
