// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ContentSection {
  /// The language of this content section
  ContentLanguage get contentLanguage => throw _privateConstructorUsedError;

  /// List of content entries in this section
  List<ContentEntry> get contentEntries => throw _privateConstructorUsedError;

  /// List of footnotes for this section
  List<String> get footnotes => throw _privateConstructorUsedError;

  /// Create a copy of ContentSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContentSectionCopyWith<ContentSection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContentSectionCopyWith<$Res> {
  factory $ContentSectionCopyWith(
          ContentSection value, $Res Function(ContentSection) then) =
      _$ContentSectionCopyWithImpl<$Res, ContentSection>;
  @useResult
  $Res call(
      {ContentLanguage contentLanguage,
      List<ContentEntry> contentEntries,
      List<String> footnotes});
}

/// @nodoc
class _$ContentSectionCopyWithImpl<$Res, $Val extends ContentSection>
    implements $ContentSectionCopyWith<$Res> {
  _$ContentSectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContentSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentLanguage = null,
    Object? contentEntries = null,
    Object? footnotes = null,
  }) {
    return _then(_value.copyWith(
      contentLanguage: null == contentLanguage
          ? _value.contentLanguage
          : contentLanguage // ignore: cast_nullable_to_non_nullable
              as ContentLanguage,
      contentEntries: null == contentEntries
          ? _value.contentEntries
          : contentEntries // ignore: cast_nullable_to_non_nullable
              as List<ContentEntry>,
      footnotes: null == footnotes
          ? _value.footnotes
          : footnotes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ContentSectionImplCopyWith<$Res>
    implements $ContentSectionCopyWith<$Res> {
  factory _$$ContentSectionImplCopyWith(_$ContentSectionImpl value,
          $Res Function(_$ContentSectionImpl) then) =
      __$$ContentSectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {ContentLanguage contentLanguage,
      List<ContentEntry> contentEntries,
      List<String> footnotes});
}

/// @nodoc
class __$$ContentSectionImplCopyWithImpl<$Res>
    extends _$ContentSectionCopyWithImpl<$Res, _$ContentSectionImpl>
    implements _$$ContentSectionImplCopyWith<$Res> {
  __$$ContentSectionImplCopyWithImpl(
      _$ContentSectionImpl _value, $Res Function(_$ContentSectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of ContentSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentLanguage = null,
    Object? contentEntries = null,
    Object? footnotes = null,
  }) {
    return _then(_$ContentSectionImpl(
      contentLanguage: null == contentLanguage
          ? _value.contentLanguage
          : contentLanguage // ignore: cast_nullable_to_non_nullable
              as ContentLanguage,
      contentEntries: null == contentEntries
          ? _value._contentEntries
          : contentEntries // ignore: cast_nullable_to_non_nullable
              as List<ContentEntry>,
      footnotes: null == footnotes
          ? _value._footnotes
          : footnotes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$ContentSectionImpl extends _ContentSection {
  const _$ContentSectionImpl(
      {required this.contentLanguage,
      final List<ContentEntry> contentEntries = const [],
      final List<String> footnotes = const []})
      : _contentEntries = contentEntries,
        _footnotes = footnotes,
        super._();

  /// The language of this content section
  @override
  final ContentLanguage contentLanguage;

  /// List of content entries in this section
  final List<ContentEntry> _contentEntries;

  /// List of content entries in this section
  @override
  @JsonKey()
  List<ContentEntry> get contentEntries {
    if (_contentEntries is EqualUnmodifiableListView) return _contentEntries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_contentEntries);
  }

  /// List of footnotes for this section
  final List<String> _footnotes;

  /// List of footnotes for this section
  @override
  @JsonKey()
  List<String> get footnotes {
    if (_footnotes is EqualUnmodifiableListView) return _footnotes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_footnotes);
  }

  @override
  String toString() {
    return 'ContentSection(contentLanguage: $contentLanguage, contentEntries: $contentEntries, footnotes: $footnotes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContentSectionImpl &&
            (identical(other.contentLanguage, contentLanguage) ||
                other.contentLanguage == contentLanguage) &&
            const DeepCollectionEquality()
                .equals(other._contentEntries, _contentEntries) &&
            const DeepCollectionEquality()
                .equals(other._footnotes, _footnotes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      contentLanguage,
      const DeepCollectionEquality().hash(_contentEntries),
      const DeepCollectionEquality().hash(_footnotes));

  /// Create a copy of ContentSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContentSectionImplCopyWith<_$ContentSectionImpl> get copyWith =>
      __$$ContentSectionImplCopyWithImpl<_$ContentSectionImpl>(
          this, _$identity);
}

abstract class _ContentSection extends ContentSection {
  const factory _ContentSection(
      {required final ContentLanguage contentLanguage,
      final List<ContentEntry> contentEntries,
      final List<String> footnotes}) = _$ContentSectionImpl;
  const _ContentSection._() : super._();

  /// The language of this content section
  @override
  ContentLanguage get contentLanguage;

  /// List of content entries in this section
  @override
  List<ContentEntry> get contentEntries;

  /// List of footnotes for this section
  @override
  List<String> get footnotes;

  /// Create a copy of ContentSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContentSectionImplCopyWith<_$ContentSectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
