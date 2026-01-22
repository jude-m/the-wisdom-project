// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dictionary_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$DictionaryEntry {
  /// Database row ID
  int get id => throw _privateConstructorUsedError;

  /// The Pali word (in Sinhala script)
  String get word => throw _privateConstructorUsedError;

  /// Dictionary identifier (e.g., 'DPD', 'PTS', 'BUS')
  String get dictionaryId => throw _privateConstructorUsedError;

  /// The meaning/definition (HTML content)
  String get meaning => throw _privateConstructorUsedError;

  /// Target language of the definition ('en' or 'si')
  String get targetLanguage => throw _privateConstructorUsedError;

  /// Source language of the word ('pali' or 'sinhala')
  String get sourceLanguage => throw _privateConstructorUsedError;

  /// Priority ranking for ordering (higher = more important)
  int get rank => throw _privateConstructorUsedError;

  /// Optional relevance score from FTS search
  double? get relevanceScore => throw _privateConstructorUsedError;

  /// Create a copy of DictionaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DictionaryEntryCopyWith<DictionaryEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DictionaryEntryCopyWith<$Res> {
  factory $DictionaryEntryCopyWith(
          DictionaryEntry value, $Res Function(DictionaryEntry) then) =
      _$DictionaryEntryCopyWithImpl<$Res, DictionaryEntry>;
  @useResult
  $Res call(
      {int id,
      String word,
      String dictionaryId,
      String meaning,
      String targetLanguage,
      String sourceLanguage,
      int rank,
      double? relevanceScore});
}

/// @nodoc
class _$DictionaryEntryCopyWithImpl<$Res, $Val extends DictionaryEntry>
    implements $DictionaryEntryCopyWith<$Res> {
  _$DictionaryEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DictionaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? word = null,
    Object? dictionaryId = null,
    Object? meaning = null,
    Object? targetLanguage = null,
    Object? sourceLanguage = null,
    Object? rank = null,
    Object? relevanceScore = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      dictionaryId: null == dictionaryId
          ? _value.dictionaryId
          : dictionaryId // ignore: cast_nullable_to_non_nullable
              as String,
      meaning: null == meaning
          ? _value.meaning
          : meaning // ignore: cast_nullable_to_non_nullable
              as String,
      targetLanguage: null == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      sourceLanguage: null == sourceLanguage
          ? _value.sourceLanguage
          : sourceLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      relevanceScore: freezed == relevanceScore
          ? _value.relevanceScore
          : relevanceScore // ignore: cast_nullable_to_non_nullable
              as double?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DictionaryEntryImplCopyWith<$Res>
    implements $DictionaryEntryCopyWith<$Res> {
  factory _$$DictionaryEntryImplCopyWith(_$DictionaryEntryImpl value,
          $Res Function(_$DictionaryEntryImpl) then) =
      __$$DictionaryEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int id,
      String word,
      String dictionaryId,
      String meaning,
      String targetLanguage,
      String sourceLanguage,
      int rank,
      double? relevanceScore});
}

/// @nodoc
class __$$DictionaryEntryImplCopyWithImpl<$Res>
    extends _$DictionaryEntryCopyWithImpl<$Res, _$DictionaryEntryImpl>
    implements _$$DictionaryEntryImplCopyWith<$Res> {
  __$$DictionaryEntryImplCopyWithImpl(
      _$DictionaryEntryImpl _value, $Res Function(_$DictionaryEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of DictionaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? word = null,
    Object? dictionaryId = null,
    Object? meaning = null,
    Object? targetLanguage = null,
    Object? sourceLanguage = null,
    Object? rank = null,
    Object? relevanceScore = freezed,
  }) {
    return _then(_$DictionaryEntryImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as int,
      word: null == word
          ? _value.word
          : word // ignore: cast_nullable_to_non_nullable
              as String,
      dictionaryId: null == dictionaryId
          ? _value.dictionaryId
          : dictionaryId // ignore: cast_nullable_to_non_nullable
              as String,
      meaning: null == meaning
          ? _value.meaning
          : meaning // ignore: cast_nullable_to_non_nullable
              as String,
      targetLanguage: null == targetLanguage
          ? _value.targetLanguage
          : targetLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      sourceLanguage: null == sourceLanguage
          ? _value.sourceLanguage
          : sourceLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      rank: null == rank
          ? _value.rank
          : rank // ignore: cast_nullable_to_non_nullable
              as int,
      relevanceScore: freezed == relevanceScore
          ? _value.relevanceScore
          : relevanceScore // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// @nodoc

class _$DictionaryEntryImpl implements _DictionaryEntry {
  const _$DictionaryEntryImpl(
      {required this.id,
      required this.word,
      required this.dictionaryId,
      required this.meaning,
      required this.targetLanguage,
      required this.sourceLanguage,
      this.rank = 0,
      this.relevanceScore});

  /// Database row ID
  @override
  final int id;

  /// The Pali word (in Sinhala script)
  @override
  final String word;

  /// Dictionary identifier (e.g., 'DPD', 'PTS', 'BUS')
  @override
  final String dictionaryId;

  /// The meaning/definition (HTML content)
  @override
  final String meaning;

  /// Target language of the definition ('en' or 'si')
  @override
  final String targetLanguage;

  /// Source language of the word ('pali' or 'sinhala')
  @override
  final String sourceLanguage;

  /// Priority ranking for ordering (higher = more important)
  @override
  @JsonKey()
  final int rank;

  /// Optional relevance score from FTS search
  @override
  final double? relevanceScore;

  @override
  String toString() {
    return 'DictionaryEntry(id: $id, word: $word, dictionaryId: $dictionaryId, meaning: $meaning, targetLanguage: $targetLanguage, sourceLanguage: $sourceLanguage, rank: $rank, relevanceScore: $relevanceScore)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DictionaryEntryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.word, word) || other.word == word) &&
            (identical(other.dictionaryId, dictionaryId) ||
                other.dictionaryId == dictionaryId) &&
            (identical(other.meaning, meaning) || other.meaning == meaning) &&
            (identical(other.targetLanguage, targetLanguage) ||
                other.targetLanguage == targetLanguage) &&
            (identical(other.sourceLanguage, sourceLanguage) ||
                other.sourceLanguage == sourceLanguage) &&
            (identical(other.rank, rank) || other.rank == rank) &&
            (identical(other.relevanceScore, relevanceScore) ||
                other.relevanceScore == relevanceScore));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, word, dictionaryId, meaning,
      targetLanguage, sourceLanguage, rank, relevanceScore);

  /// Create a copy of DictionaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DictionaryEntryImplCopyWith<_$DictionaryEntryImpl> get copyWith =>
      __$$DictionaryEntryImplCopyWithImpl<_$DictionaryEntryImpl>(
          this, _$identity);
}

abstract class _DictionaryEntry implements DictionaryEntry {
  const factory _DictionaryEntry(
      {required final int id,
      required final String word,
      required final String dictionaryId,
      required final String meaning,
      required final String targetLanguage,
      required final String sourceLanguage,
      final int rank,
      final double? relevanceScore}) = _$DictionaryEntryImpl;

  /// Database row ID
  @override
  int get id;

  /// The Pali word (in Sinhala script)
  @override
  String get word;

  /// Dictionary identifier (e.g., 'DPD', 'PTS', 'BUS')
  @override
  String get dictionaryId;

  /// The meaning/definition (HTML content)
  @override
  String get meaning;

  /// Target language of the definition ('en' or 'si')
  @override
  String get targetLanguage;

  /// Source language of the word ('pali' or 'sinhala')
  @override
  String get sourceLanguage;

  /// Priority ranking for ordering (higher = more important)
  @override
  int get rank;

  /// Optional relevance score from FTS search
  @override
  double? get relevanceScore;

  /// Create a copy of DictionaryEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DictionaryEntryImplCopyWith<_$DictionaryEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
