// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bjt_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BJTPage {
  /// The page number in the original text
  int get pageNumber => throw _privateConstructorUsedError;

  /// Pali section for this page
  BJTSection get paliSection => throw _privateConstructorUsedError;

  /// Sinhala section for this page
  BJTSection get sinhalaSection => throw _privateConstructorUsedError;

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BJTPageCopyWith<BJTPage> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BJTPageCopyWith<$Res> {
  factory $BJTPageCopyWith(BJTPage value, $Res Function(BJTPage) then) =
      _$BJTPageCopyWithImpl<$Res, BJTPage>;
  @useResult
  $Res call(
      {int pageNumber, BJTSection paliSection, BJTSection sinhalaSection});

  $BJTSectionCopyWith<$Res> get paliSection;
  $BJTSectionCopyWith<$Res> get sinhalaSection;
}

/// @nodoc
class _$BJTPageCopyWithImpl<$Res, $Val extends BJTPage>
    implements $BJTPageCopyWith<$Res> {
  _$BJTPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageNumber = null,
    Object? paliSection = null,
    Object? sinhalaSection = null,
  }) {
    return _then(_value.copyWith(
      pageNumber: null == pageNumber
          ? _value.pageNumber
          : pageNumber // ignore: cast_nullable_to_non_nullable
              as int,
      paliSection: null == paliSection
          ? _value.paliSection
          : paliSection // ignore: cast_nullable_to_non_nullable
              as BJTSection,
      sinhalaSection: null == sinhalaSection
          ? _value.sinhalaSection
          : sinhalaSection // ignore: cast_nullable_to_non_nullable
              as BJTSection,
    ) as $Val);
  }

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BJTSectionCopyWith<$Res> get paliSection {
    return $BJTSectionCopyWith<$Res>(_value.paliSection, (value) {
      return _then(_value.copyWith(paliSection: value) as $Val);
    });
  }

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BJTSectionCopyWith<$Res> get sinhalaSection {
    return $BJTSectionCopyWith<$Res>(_value.sinhalaSection, (value) {
      return _then(_value.copyWith(sinhalaSection: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$BJTPageImplCopyWith<$Res> implements $BJTPageCopyWith<$Res> {
  factory _$$BJTPageImplCopyWith(
          _$BJTPageImpl value, $Res Function(_$BJTPageImpl) then) =
      __$$BJTPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int pageNumber, BJTSection paliSection, BJTSection sinhalaSection});

  @override
  $BJTSectionCopyWith<$Res> get paliSection;
  @override
  $BJTSectionCopyWith<$Res> get sinhalaSection;
}

/// @nodoc
class __$$BJTPageImplCopyWithImpl<$Res>
    extends _$BJTPageCopyWithImpl<$Res, _$BJTPageImpl>
    implements _$$BJTPageImplCopyWith<$Res> {
  __$$BJTPageImplCopyWithImpl(
      _$BJTPageImpl _value, $Res Function(_$BJTPageImpl) _then)
      : super(_value, _then);

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageNumber = null,
    Object? paliSection = null,
    Object? sinhalaSection = null,
  }) {
    return _then(_$BJTPageImpl(
      pageNumber: null == pageNumber
          ? _value.pageNumber
          : pageNumber // ignore: cast_nullable_to_non_nullable
              as int,
      paliSection: null == paliSection
          ? _value.paliSection
          : paliSection // ignore: cast_nullable_to_non_nullable
              as BJTSection,
      sinhalaSection: null == sinhalaSection
          ? _value.sinhalaSection
          : sinhalaSection // ignore: cast_nullable_to_non_nullable
              as BJTSection,
    ));
  }
}

/// @nodoc

class _$BJTPageImpl extends _BJTPage {
  const _$BJTPageImpl(
      {required this.pageNumber,
      required this.paliSection,
      required this.sinhalaSection})
      : super._();

  /// The page number in the original text
  @override
  final int pageNumber;

  /// Pali section for this page
  @override
  final BJTSection paliSection;

  /// Sinhala section for this page
  @override
  final BJTSection sinhalaSection;

  @override
  String toString() {
    return 'BJTPage(pageNumber: $pageNumber, paliSection: $paliSection, sinhalaSection: $sinhalaSection)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BJTPageImpl &&
            (identical(other.pageNumber, pageNumber) ||
                other.pageNumber == pageNumber) &&
            (identical(other.paliSection, paliSection) ||
                other.paliSection == paliSection) &&
            (identical(other.sinhalaSection, sinhalaSection) ||
                other.sinhalaSection == sinhalaSection));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, pageNumber, paliSection, sinhalaSection);

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BJTPageImplCopyWith<_$BJTPageImpl> get copyWith =>
      __$$BJTPageImplCopyWithImpl<_$BJTPageImpl>(this, _$identity);
}

abstract class _BJTPage extends BJTPage {
  const factory _BJTPage(
      {required final int pageNumber,
      required final BJTSection paliSection,
      required final BJTSection sinhalaSection}) = _$BJTPageImpl;
  const _BJTPage._() : super._();

  /// The page number in the original text
  @override
  int get pageNumber;

  /// Pali section for this page
  @override
  BJTSection get paliSection;

  /// Sinhala section for this page
  @override
  BJTSection get sinhalaSection;

  /// Create a copy of BJTPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BJTPageImplCopyWith<_$BJTPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
