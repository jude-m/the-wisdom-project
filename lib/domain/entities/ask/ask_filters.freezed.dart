// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ask_filters.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AskFilters _$AskFiltersFromJson(Map<String, dynamic> json) {
  return _AskFilters.fromJson(json);
}

/// @nodoc
mixin _$AskFilters {
  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  String? get basket => throw _privateConstructorUsedError;

  /// Serializes this AskFilters to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AskFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AskFiltersCopyWith<AskFilters> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AskFiltersCopyWith<$Res> {
  factory $AskFiltersCopyWith(
          AskFilters value, $Res Function(AskFilters) then) =
      _$AskFiltersCopyWithImpl<$Res, AskFilters>;
  @useResult
  $Res call({String? basket});
}

/// @nodoc
class _$AskFiltersCopyWithImpl<$Res, $Val extends AskFilters>
    implements $AskFiltersCopyWith<$Res> {
  _$AskFiltersCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AskFilters
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? basket = freezed,
  }) {
    return _then(_value.copyWith(
      basket: freezed == basket
          ? _value.basket
          : basket // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AskFiltersImplCopyWith<$Res>
    implements $AskFiltersCopyWith<$Res> {
  factory _$$AskFiltersImplCopyWith(
          _$AskFiltersImpl value, $Res Function(_$AskFiltersImpl) then) =
      __$$AskFiltersImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? basket});
}

/// @nodoc
class __$$AskFiltersImplCopyWithImpl<$Res>
    extends _$AskFiltersCopyWithImpl<$Res, _$AskFiltersImpl>
    implements _$$AskFiltersImplCopyWith<$Res> {
  __$$AskFiltersImplCopyWithImpl(
      _$AskFiltersImpl _value, $Res Function(_$AskFiltersImpl) _then)
      : super(_value, _then);

  /// Create a copy of AskFilters
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? basket = freezed,
  }) {
    return _then(_$AskFiltersImpl(
      basket: freezed == basket
          ? _value.basket
          : basket // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AskFiltersImpl implements _AskFilters {
  const _$AskFiltersImpl({this.basket});

  factory _$AskFiltersImpl.fromJson(Map<String, dynamic> json) =>
      _$$AskFiltersImplFromJson(json);

  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  @override
  final String? basket;

  @override
  String toString() {
    return 'AskFilters(basket: $basket)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AskFiltersImpl &&
            (identical(other.basket, basket) || other.basket == basket));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, basket);

  /// Create a copy of AskFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AskFiltersImplCopyWith<_$AskFiltersImpl> get copyWith =>
      __$$AskFiltersImplCopyWithImpl<_$AskFiltersImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AskFiltersImplToJson(
      this,
    );
  }
}

abstract class _AskFilters implements AskFilters {
  const factory _AskFilters({final String? basket}) = _$AskFiltersImpl;

  factory _AskFilters.fromJson(Map<String, dynamic> json) =
      _$AskFiltersImpl.fromJson;

  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  @override
  String? get basket;

  /// Create a copy of AskFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AskFiltersImplCopyWith<_$AskFiltersImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
