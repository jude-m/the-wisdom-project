// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'text_content.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TextContent {
  /// The unique identifier for this content (filename without extension)
  String get contentFileId => throw _privateConstructorUsedError;

  /// List of pages containing the actual content
  List<ContentPage> get contentPages => throw _privateConstructorUsedError;

  /// Create a copy of TextContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TextContentCopyWith<TextContent> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TextContentCopyWith<$Res> {
  factory $TextContentCopyWith(
          TextContent value, $Res Function(TextContent) then) =
      _$TextContentCopyWithImpl<$Res, TextContent>;
  @useResult
  $Res call({String contentFileId, List<ContentPage> contentPages});
}

/// @nodoc
class _$TextContentCopyWithImpl<$Res, $Val extends TextContent>
    implements $TextContentCopyWith<$Res> {
  _$TextContentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TextContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentFileId = null,
    Object? contentPages = null,
  }) {
    return _then(_value.copyWith(
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      contentPages: null == contentPages
          ? _value.contentPages
          : contentPages // ignore: cast_nullable_to_non_nullable
              as List<ContentPage>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TextContentImplCopyWith<$Res>
    implements $TextContentCopyWith<$Res> {
  factory _$$TextContentImplCopyWith(
          _$TextContentImpl value, $Res Function(_$TextContentImpl) then) =
      __$$TextContentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String contentFileId, List<ContentPage> contentPages});
}

/// @nodoc
class __$$TextContentImplCopyWithImpl<$Res>
    extends _$TextContentCopyWithImpl<$Res, _$TextContentImpl>
    implements _$$TextContentImplCopyWith<$Res> {
  __$$TextContentImplCopyWithImpl(
      _$TextContentImpl _value, $Res Function(_$TextContentImpl) _then)
      : super(_value, _then);

  /// Create a copy of TextContent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? contentFileId = null,
    Object? contentPages = null,
  }) {
    return _then(_$TextContentImpl(
      contentFileId: null == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String,
      contentPages: null == contentPages
          ? _value._contentPages
          : contentPages // ignore: cast_nullable_to_non_nullable
              as List<ContentPage>,
    ));
  }
}

/// @nodoc

class _$TextContentImpl extends _TextContent {
  const _$TextContentImpl(
      {required this.contentFileId,
      final List<ContentPage> contentPages = const []})
      : _contentPages = contentPages,
        super._();

  /// The unique identifier for this content (filename without extension)
  @override
  final String contentFileId;

  /// List of pages containing the actual content
  final List<ContentPage> _contentPages;

  /// List of pages containing the actual content
  @override
  @JsonKey()
  List<ContentPage> get contentPages {
    if (_contentPages is EqualUnmodifiableListView) return _contentPages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_contentPages);
  }

  @override
  String toString() {
    return 'TextContent(contentFileId: $contentFileId, contentPages: $contentPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextContentImpl &&
            (identical(other.contentFileId, contentFileId) ||
                other.contentFileId == contentFileId) &&
            const DeepCollectionEquality()
                .equals(other._contentPages, _contentPages));
  }

  @override
  int get hashCode => Object.hash(runtimeType, contentFileId,
      const DeepCollectionEquality().hash(_contentPages));

  /// Create a copy of TextContent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextContentImplCopyWith<_$TextContentImpl> get copyWith =>
      __$$TextContentImplCopyWithImpl<_$TextContentImpl>(this, _$identity);
}

abstract class _TextContent extends TextContent {
  const factory _TextContent(
      {required final String contentFileId,
      final List<ContentPage> contentPages}) = _$TextContentImpl;
  const _TextContent._() : super._();

  /// The unique identifier for this content (filename without extension)
  @override
  String get contentFileId;

  /// List of pages containing the actual content
  @override
  List<ContentPage> get contentPages;

  /// Create a copy of TextContent
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextContentImplCopyWith<_$TextContentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
