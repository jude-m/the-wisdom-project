// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ContentPage {
  /// The page number in the original text
  int get pageNumber => throw _privateConstructorUsedError;

  /// Pali content section for this page
  ContentSection get paliContentSection => throw _privateConstructorUsedError;

  /// Sinhala content section for this page
  ContentSection get sinhalaContentSection =>
      throw _privateConstructorUsedError;

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContentPageCopyWith<ContentPage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContentPageCopyWith<$Res> {
  factory $ContentPageCopyWith(
          ContentPage value, $Res Function(ContentPage) then) =
      _$ContentPageCopyWithImpl<$Res, ContentPage>;
  @useResult
  $Res call(
      {int pageNumber,
      ContentSection paliContentSection,
      ContentSection sinhalaContentSection});

  $ContentSectionCopyWith<$Res> get paliContentSection;
  $ContentSectionCopyWith<$Res> get sinhalaContentSection;
}

/// @nodoc
class _$ContentPageCopyWithImpl<$Res, $Val extends ContentPage>
    implements $ContentPageCopyWith<$Res> {
  _$ContentPageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageNumber = null,
    Object? paliContentSection = null,
    Object? sinhalaContentSection = null,
  }) {
    return _then(_value.copyWith(
      pageNumber: null == pageNumber
          ? _value.pageNumber
          : pageNumber // ignore: cast_nullable_to_non_nullable
              as int,
      paliContentSection: null == paliContentSection
          ? _value.paliContentSection
          : paliContentSection // ignore: cast_nullable_to_non_nullable
              as ContentSection,
      sinhalaContentSection: null == sinhalaContentSection
          ? _value.sinhalaContentSection
          : sinhalaContentSection // ignore: cast_nullable_to_non_nullable
              as ContentSection,
    ) as $Val);
  }

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentSectionCopyWith<$Res> get paliContentSection {
    return $ContentSectionCopyWith<$Res>(_value.paliContentSection, (value) {
      return _then(_value.copyWith(paliContentSection: value) as $Val);
    });
  }

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ContentSectionCopyWith<$Res> get sinhalaContentSection {
    return $ContentSectionCopyWith<$Res>(_value.sinhalaContentSection, (value) {
      return _then(_value.copyWith(sinhalaContentSection: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ContentPageImplCopyWith<$Res>
    implements $ContentPageCopyWith<$Res> {
  factory _$$ContentPageImplCopyWith(
          _$ContentPageImpl value, $Res Function(_$ContentPageImpl) then) =
      __$$ContentPageImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int pageNumber,
      ContentSection paliContentSection,
      ContentSection sinhalaContentSection});

  @override
  $ContentSectionCopyWith<$Res> get paliContentSection;
  @override
  $ContentSectionCopyWith<$Res> get sinhalaContentSection;
}

/// @nodoc
class __$$ContentPageImplCopyWithImpl<$Res>
    extends _$ContentPageCopyWithImpl<$Res, _$ContentPageImpl>
    implements _$$ContentPageImplCopyWith<$Res> {
  __$$ContentPageImplCopyWithImpl(
      _$ContentPageImpl _value, $Res Function(_$ContentPageImpl) _then)
      : super(_value, _then);

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? pageNumber = null,
    Object? paliContentSection = null,
    Object? sinhalaContentSection = null,
  }) {
    return _then(_$ContentPageImpl(
      pageNumber: null == pageNumber
          ? _value.pageNumber
          : pageNumber // ignore: cast_nullable_to_non_nullable
              as int,
      paliContentSection: null == paliContentSection
          ? _value.paliContentSection
          : paliContentSection // ignore: cast_nullable_to_non_nullable
              as ContentSection,
      sinhalaContentSection: null == sinhalaContentSection
          ? _value.sinhalaContentSection
          : sinhalaContentSection // ignore: cast_nullable_to_non_nullable
              as ContentSection,
    ));
  }
}

/// @nodoc

class _$ContentPageImpl extends _ContentPage {
  const _$ContentPageImpl(
      {required this.pageNumber,
      required this.paliContentSection,
      required this.sinhalaContentSection})
      : super._();

  /// The page number in the original text
  @override
  final int pageNumber;

  /// Pali content section for this page
  @override
  final ContentSection paliContentSection;

  /// Sinhala content section for this page
  @override
  final ContentSection sinhalaContentSection;

  @override
  String toString() {
    return 'ContentPage(pageNumber: $pageNumber, paliContentSection: $paliContentSection, sinhalaContentSection: $sinhalaContentSection)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContentPageImpl &&
            (identical(other.pageNumber, pageNumber) ||
                other.pageNumber == pageNumber) &&
            (identical(other.paliContentSection, paliContentSection) ||
                other.paliContentSection == paliContentSection) &&
            (identical(other.sinhalaContentSection, sinhalaContentSection) ||
                other.sinhalaContentSection == sinhalaContentSection));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, pageNumber, paliContentSection, sinhalaContentSection);

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContentPageImplCopyWith<_$ContentPageImpl> get copyWith =>
      __$$ContentPageImplCopyWithImpl<_$ContentPageImpl>(this, _$identity);
}

abstract class _ContentPage extends ContentPage {
  const factory _ContentPage(
      {required final int pageNumber,
      required final ContentSection paliContentSection,
      required final ContentSection sinhalaContentSection}) = _$ContentPageImpl;
  const _ContentPage._() : super._();

  /// The page number in the original text
  @override
  int get pageNumber;

  /// Pali content section for this page
  @override
  ContentSection get paliContentSection;

  /// Sinhala content section for this page
  @override
  ContentSection get sinhalaContentSection;

  /// Create a copy of ContentPage
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContentPageImplCopyWith<_$ContentPageImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
