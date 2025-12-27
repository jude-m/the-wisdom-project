// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'edition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Edition {
  /// Unique identifier for this edition
  /// Examples: 'bjt', 'suttacentral', 'pts'
  String get editionId => throw _privateConstructorUsedError;

  /// Human-readable display name
  /// Examples: 'Buddha Jayanti Tripitaka', 'SuttaCentral', 'Pali Text Society'
  String get displayName => throw _privateConstructorUsedError;

  /// Short abbreviation for UI display
  /// Examples: 'BJT', 'SC', 'PTS'
  String get abbreviation => throw _privateConstructorUsedError;

  /// Type of edition (local files vs remote API)
  EditionType get type => throw _privateConstructorUsedError;

  /// Language codes available in this edition
  /// Uses ISO 639-1 codes: 'pi' (Pali), 'si' (Sinhala), 'en' (English), etc.
  List<String> get availableLanguages => throw _privateConstructorUsedError;

  /// Create a copy of Edition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EditionCopyWith<Edition> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EditionCopyWith<$Res> {
  factory $EditionCopyWith(Edition value, $Res Function(Edition) then) =
      _$EditionCopyWithImpl<$Res, Edition>;
  @useResult
  $Res call(
      {String editionId,
      String displayName,
      String abbreviation,
      EditionType type,
      List<String> availableLanguages});
}

/// @nodoc
class _$EditionCopyWithImpl<$Res, $Val extends Edition>
    implements $EditionCopyWith<$Res> {
  _$EditionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Edition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editionId = null,
    Object? displayName = null,
    Object? abbreviation = null,
    Object? type = null,
    Object? availableLanguages = null,
  }) {
    return _then(_value.copyWith(
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      abbreviation: null == abbreviation
          ? _value.abbreviation
          : abbreviation // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as EditionType,
      availableLanguages: null == availableLanguages
          ? _value.availableLanguages
          : availableLanguages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EditionImplCopyWith<$Res> implements $EditionCopyWith<$Res> {
  factory _$$EditionImplCopyWith(
          _$EditionImpl value, $Res Function(_$EditionImpl) then) =
      __$$EditionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String editionId,
      String displayName,
      String abbreviation,
      EditionType type,
      List<String> availableLanguages});
}

/// @nodoc
class __$$EditionImplCopyWithImpl<$Res>
    extends _$EditionCopyWithImpl<$Res, _$EditionImpl>
    implements _$$EditionImplCopyWith<$Res> {
  __$$EditionImplCopyWithImpl(
      _$EditionImpl _value, $Res Function(_$EditionImpl) _then)
      : super(_value, _then);

  /// Create a copy of Edition
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editionId = null,
    Object? displayName = null,
    Object? abbreviation = null,
    Object? type = null,
    Object? availableLanguages = null,
  }) {
    return _then(_$EditionImpl(
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      displayName: null == displayName
          ? _value.displayName
          : displayName // ignore: cast_nullable_to_non_nullable
              as String,
      abbreviation: null == abbreviation
          ? _value.abbreviation
          : abbreviation // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as EditionType,
      availableLanguages: null == availableLanguages
          ? _value._availableLanguages
          : availableLanguages // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$EditionImpl implements _Edition {
  const _$EditionImpl(
      {required this.editionId,
      required this.displayName,
      required this.abbreviation,
      required this.type,
      final List<String> availableLanguages = const []})
      : _availableLanguages = availableLanguages;

  /// Unique identifier for this edition
  /// Examples: 'bjt', 'suttacentral', 'pts'
  @override
  final String editionId;

  /// Human-readable display name
  /// Examples: 'Buddha Jayanti Tripitaka', 'SuttaCentral', 'Pali Text Society'
  @override
  final String displayName;

  /// Short abbreviation for UI display
  /// Examples: 'BJT', 'SC', 'PTS'
  @override
  final String abbreviation;

  /// Type of edition (local files vs remote API)
  @override
  final EditionType type;

  /// Language codes available in this edition
  /// Uses ISO 639-1 codes: 'pi' (Pali), 'si' (Sinhala), 'en' (English), etc.
  final List<String> _availableLanguages;

  /// Language codes available in this edition
  /// Uses ISO 639-1 codes: 'pi' (Pali), 'si' (Sinhala), 'en' (English), etc.
  @override
  @JsonKey()
  List<String> get availableLanguages {
    if (_availableLanguages is EqualUnmodifiableListView)
      return _availableLanguages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableLanguages);
  }

  @override
  String toString() {
    return 'Edition(editionId: $editionId, displayName: $displayName, abbreviation: $abbreviation, type: $type, availableLanguages: $availableLanguages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EditionImpl &&
            (identical(other.editionId, editionId) ||
                other.editionId == editionId) &&
            (identical(other.displayName, displayName) ||
                other.displayName == displayName) &&
            (identical(other.abbreviation, abbreviation) ||
                other.abbreviation == abbreviation) &&
            (identical(other.type, type) || other.type == type) &&
            const DeepCollectionEquality()
                .equals(other._availableLanguages, _availableLanguages));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      editionId,
      displayName,
      abbreviation,
      type,
      const DeepCollectionEquality().hash(_availableLanguages));

  /// Create a copy of Edition
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EditionImplCopyWith<_$EditionImpl> get copyWith =>
      __$$EditionImplCopyWithImpl<_$EditionImpl>(this, _$identity);
}

abstract class _Edition implements Edition {
  const factory _Edition(
      {required final String editionId,
      required final String displayName,
      required final String abbreviation,
      required final EditionType type,
      final List<String> availableLanguages}) = _$EditionImpl;

  /// Unique identifier for this edition
  /// Examples: 'bjt', 'suttacentral', 'pts'
  @override
  String get editionId;

  /// Human-readable display name
  /// Examples: 'Buddha Jayanti Tripitaka', 'SuttaCentral', 'Pali Text Society'
  @override
  String get displayName;

  /// Short abbreviation for UI display
  /// Examples: 'BJT', 'SC', 'PTS'
  @override
  String get abbreviation;

  /// Type of edition (local files vs remote API)
  @override
  EditionType get type;

  /// Language codes available in this edition
  /// Uses ISO 639-1 codes: 'pi' (Pali), 'si' (Sinhala), 'en' (English), etc.
  @override
  List<String> get availableLanguages;

  /// Create a copy of Edition
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EditionImplCopyWith<_$EditionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
