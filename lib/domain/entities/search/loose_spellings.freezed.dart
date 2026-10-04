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
  List<List<String>> get words => throw _privateConstructorUsedError;

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
  $Res call({List<List<String>> words});
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
  }) {
    return _then(_value.copyWith(
      words: null == words
          ? _value.words
          : words // ignore: cast_nullable_to_non_nullable
              as List<List<String>>,
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
  $Res call({List<List<String>> words});
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
  }) {
    return _then(_$LooseSpellingsImpl(
      words: null == words
          ? _value._words
          : words // ignore: cast_nullable_to_non_nullable
              as List<List<String>>,
    ));
  }
}

/// @nodoc

class _$LooseSpellingsImpl extends _LooseSpellings {
  const _$LooseSpellingsImpl({final List<List<String>> words = const []})
      : _words = words,
        super._();

  final List<List<String>> _words;
  @override
  @JsonKey()
  List<List<String>> get words {
    if (_words is EqualUnmodifiableListView) return _words;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_words);
  }

  @override
  String toString() {
    return 'LooseSpellings(words: $words)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$LooseSpellingsImpl &&
            const DeepCollectionEquality().equals(other._words, _words));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(_words));

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$LooseSpellingsImplCopyWith<_$LooseSpellingsImpl> get copyWith =>
      __$$LooseSpellingsImplCopyWithImpl<_$LooseSpellingsImpl>(
          this, _$identity);
}

abstract class _LooseSpellings extends LooseSpellings {
  const factory _LooseSpellings({final List<List<String>> words}) =
      _$LooseSpellingsImpl;
  const _LooseSpellings._() : super._();

  @override
  List<List<String>> get words;

  /// Create a copy of LooseSpellings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$LooseSpellingsImplCopyWith<_$LooseSpellingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
