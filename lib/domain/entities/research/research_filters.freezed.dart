// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'research_filters.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

ResearchFilters _$ResearchFiltersFromJson(Map<String, dynamic> json) {
  return _ResearchFilters.fromJson(json);
}

/// @nodoc
mixin _$ResearchFilters {
  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  String? get basket => throw _privateConstructorUsedError;

  /// Serializes this ResearchFilters to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ResearchFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ResearchFiltersCopyWith<ResearchFilters> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ResearchFiltersCopyWith<$Res> {
  factory $ResearchFiltersCopyWith(
          ResearchFilters value, $Res Function(ResearchFilters) then) =
      _$ResearchFiltersCopyWithImpl<$Res, ResearchFilters>;
  @useResult
  $Res call({String? basket});
}

/// @nodoc
class _$ResearchFiltersCopyWithImpl<$Res, $Val extends ResearchFilters>
    implements $ResearchFiltersCopyWith<$Res> {
  _$ResearchFiltersCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ResearchFilters
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
abstract class _$$ResearchFiltersImplCopyWith<$Res>
    implements $ResearchFiltersCopyWith<$Res> {
  factory _$$ResearchFiltersImplCopyWith(_$ResearchFiltersImpl value,
          $Res Function(_$ResearchFiltersImpl) then) =
      __$$ResearchFiltersImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String? basket});
}

/// @nodoc
class __$$ResearchFiltersImplCopyWithImpl<$Res>
    extends _$ResearchFiltersCopyWithImpl<$Res, _$ResearchFiltersImpl>
    implements _$$ResearchFiltersImplCopyWith<$Res> {
  __$$ResearchFiltersImplCopyWithImpl(
      _$ResearchFiltersImpl _value, $Res Function(_$ResearchFiltersImpl) _then)
      : super(_value, _then);

  /// Create a copy of ResearchFilters
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? basket = freezed,
  }) {
    return _then(_$ResearchFiltersImpl(
      basket: freezed == basket
          ? _value.basket
          : basket // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ResearchFiltersImpl implements _ResearchFilters {
  const _$ResearchFiltersImpl({this.basket});

  factory _$ResearchFiltersImpl.fromJson(Map<String, dynamic> json) =>
      _$$ResearchFiltersImplFromJson(json);

  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  @override
  final String? basket;

  @override
  String toString() {
    return 'ResearchFilters(basket: $basket)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ResearchFiltersImpl &&
            (identical(other.basket, basket) || other.basket == basket));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, basket);

  /// Create a copy of ResearchFilters
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ResearchFiltersImplCopyWith<_$ResearchFiltersImpl> get copyWith =>
      __$$ResearchFiltersImplCopyWithImpl<_$ResearchFiltersImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ResearchFiltersImplToJson(
      this,
    );
  }
}

abstract class _ResearchFilters implements ResearchFilters {
  const factory _ResearchFilters({final String? basket}) =
      _$ResearchFiltersImpl;

  factory _ResearchFilters.fromJson(Map<String, dynamic> json) =
      _$ResearchFiltersImpl.fromJson;

  /// "vinaya" | "sutta" — the uid-derived basket (design §5.2).
  @override
  String? get basket;

  /// Create a copy of ResearchFilters
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ResearchFiltersImplCopyWith<_$ResearchFiltersImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
