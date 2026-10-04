// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'loose_spellings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$LooseSpellings {
  /// Per typed word, in typed order: the spellings the Tipitaka text holds,
  /// in search order. The strict search's own spelling leads unless a far
  /// more common one outranks it; the rest follow by how often the text
  /// uses them, the rarest dropped. Titles, full text and highlights search
  /// with these (see SearchQuery.leadText).
  List<List<String>> get words => throw _privateConstructorUsedError;

  /// The spellings dictionary headwords hold, for definitions, the ones the
  /// text uses most first. A headword is one word, so only a one-word query
  /// has any.
  List<String> get headwords => throw _privateConstructorUsedError;

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $LooseSpellingsCopyWith<LooseSpellings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $LooseSpellingsCopyWith<$Res> {
  factory $LooseSpellingsCopyWith(
          LooseSpellings value, $Res Function(LooseSpellings) then) =
      _$LooseSpellingsCopyWithImpl<$Res, LooseSpellings>;
  @useResult
  $Res call({List<List<String>> words, List<String> headwords});
}

/// @nodoc
class _$LooseSpellingsCopyWithImpl<$Res, $Val extends LooseSpellings>
    implements $LooseSpellingsCopyWith<$Res> {
  _$LooseSpellingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = null,
    Object? headwords = null,
  }) {
    return _then(_value.copyWith(
      words: null == words
          ? _value.words
          : words // ignore: cast_nullable_to_non_nullable
              as List<List<String>>,
      headwords: null == headwords
          ? _value.headwords
          : headwords // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$LooseSpellingsImplCopyWith<$Res>
    implements $LooseSpellingsCopyWith<$Res> {
  factory _$$LooseSpellingsImplCopyWith(_$LooseSpellingsImpl value,
          $Res Function(_$LooseSpellingsImpl) then) =
      __$$LooseSpellingsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<List<String>> words, List<String> headwords});
}

/// @nodoc
class __$$LooseSpellingsImplCopyWithImpl<$Res>
    extends _$LooseSpellingsCopyWithImpl<$Res, _$LooseSpellingsImpl>
    implements _$$LooseSpellingsImplCopyWith<$Res> {
  __$$LooseSpellingsImplCopyWithImpl(
      _$LooseSpellingsImpl _value, $Res Function(_$LooseSpellingsImpl) _then)
      : super(_value, _then);

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? words = null,
    Object? headwords = null,
  }) {
    return _then(_$LooseSpellingsImpl(
      words: null == words
          ? _value._words
          : words // ignore: cast_nullable_to_non_nullable
              as List<List<String>>,
      headwords: null == headwords
          ? _value._headwords
          : headwords // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$LooseSpellingsImpl implements _LooseSpellings {
  const _$LooseSpellingsImpl(
      {final List<List<String>> words = const [],
      final List<String> headwords = const []})
      : _words = words,
        _headwords = headwords;

  /// Per typed word, in typed order: the spellings the Tipitaka text holds,
  /// in search order. The strict search's own spelling leads unless a far
  /// more common one outranks it; the rest follow by how often the text
  /// uses them, the rarest dropped. Titles, full text and highlights search
  /// with these (see SearchQuery.leadText).
  final List<List<String>> _words;

  /// Per typed word, in typed order: the spellings the Tipitaka text holds,
  /// in search order. The strict search's own spelling leads unless a far
  /// more common one outranks it; the rest follow by how often the text
  /// uses them, the rarest dropped. Titles, full text and highlights search
  /// with these (see SearchQuery.leadText).
  @override
  @JsonKey()
  List<List<String>> get words {
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_words);
  }

  /// The spellings dictionary headwords hold, for definitions, the ones the
  /// text uses most first. A headword is one word, so only a one-word query
  /// has any.
  final List<String> _headwords;

  /// The spellings dictionary headwords hold, for definitions, the ones the
  /// text uses most first. A headword is one word, so only a one-word query
  /// has any.
  @override
  @JsonKey()
  List<String> get headwords {
    if (_headwords is EqualUnmodifiableListView) return _headwords;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_headwords);
  }

  @override
  String toString() {
    return 'LooseSpellings(words: $words, headwords: $headwords)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LooseSpellingsImpl &&
            const DeepCollectionEquality().equals(other._words, _words) &&
            const DeepCollectionEquality()
                .equals(other._headwords, _headwords));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_words),
      const DeepCollectionEquality().hash(_headwords));

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LooseSpellingsImplCopyWith<_$LooseSpellingsImpl> get copyWith =>
      __$$LooseSpellingsImplCopyWithImpl<_$LooseSpellingsImpl>(
          this, _$identity);
}

abstract class _LooseSpellings implements LooseSpellings {
  const factory _LooseSpellings(
      {final List<List<String>> words,
      final List<String> headwords}) = _$LooseSpellingsImpl;

  /// Per typed word, in typed order: the spellings the Tipitaka text holds,
  /// in search order. The strict search's own spelling leads unless a far
  /// more common one outranks it; the rest follow by how often the text
  /// uses them, the rarest dropped. Titles, full text and highlights search
  /// with these (see SearchQuery.leadText).
  @override
  List<List<String>> get words;

  /// The spellings dictionary headwords hold, for definitions, the ones the
  /// text uses most first. A headword is one word, so only a one-word query
  /// has any.
  @override
  List<String> get headwords;

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LooseSpellingsImplCopyWith<_$LooseSpellingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
