// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bjt_document.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BJTDocument {
  /// The unique identifier for this document (filename without extension)
  String get fileId => throw _privateConstructorUsedError;

  /// List of pages containing the text
  List<BJTPage> get pages => throw _privateConstructorUsedError;

  /// Edition identifier - always 'bjt' for this class
  String get editionId => throw _privateConstructorUsedError;

  /// Create a copy of BJTDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BJTDocumentCopyWith<BJTDocument> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BJTDocumentCopyWith<$Res> {
  factory $BJTDocumentCopyWith(
          BJTDocument value, $Res Function(BJTDocument) then) =
      _$BJTDocumentCopyWithImpl<$Res, BJTDocument>;
  @useResult
  $Res call({String fileId, List<BJTPage> pages, String editionId});
}

/// @nodoc
class _$BJTDocumentCopyWithImpl<$Res, $Val extends BJTDocument>
    implements $BJTDocumentCopyWith<$Res> {
  _$BJTDocumentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BJTDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileId = null,
    Object? pages = null,
    Object? editionId = null,
  }) {
    return _then(_value.copyWith(
      fileId: null == fileId
          ? _value.fileId
          : fileId // ignore: cast_nullable_to_non_nullable
              as String,
      pages: null == pages
          ? _value.pages
          : pages // ignore: cast_nullable_to_non_nullable
              as List<BJTPage>,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BJTDocumentImplCopyWith<$Res>
    implements $BJTDocumentCopyWith<$Res> {
  factory _$$BJTDocumentImplCopyWith(
          _$BJTDocumentImpl value, $Res Function(_$BJTDocumentImpl) then) =
      __$$BJTDocumentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String fileId, List<BJTPage> pages, String editionId});
}

/// @nodoc
class __$$BJTDocumentImplCopyWithImpl<$Res>
    extends _$BJTDocumentCopyWithImpl<$Res, _$BJTDocumentImpl>
    implements _$$BJTDocumentImplCopyWith<$Res> {
  __$$BJTDocumentImplCopyWithImpl(
      _$BJTDocumentImpl _value, $Res Function(_$BJTDocumentImpl) _then)
      : super(_value, _then);

  /// Create a copy of BJTDocument
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fileId = null,
    Object? pages = null,
    Object? editionId = null,
  }) {
    return _then(_$BJTDocumentImpl(
      fileId: null == fileId
          ? _value.fileId
          : fileId // ignore: cast_nullable_to_non_nullable
              as String,
      pages: null == pages
          ? _value._pages
          : pages // ignore: cast_nullable_to_non_nullable
              as List<BJTPage>,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class _$BJTDocumentImpl extends _BJTDocument {
  const _$BJTDocumentImpl(
      {required this.fileId,
      final List<BJTPage> pages = const [],
      this.editionId = 'bjt'})
      : _pages = pages,
        super._();

  /// The unique identifier for this document (filename without extension)
  @override
  final String fileId;

  /// List of pages containing the text
  final List<BJTPage> _pages;

  /// List of pages containing the text
  @override
  @JsonKey()
  List<BJTPage> get pages {
    if (_pages is EqualUnmodifiableListView) return _pages;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_pages);
  }

  /// Edition identifier - always 'bjt' for this class
  @override
  @JsonKey()
  final String editionId;

  @override
  String toString() {
    return 'BJTDocument(fileId: $fileId, pages: $pages, editionId: $editionId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BJTDocumentImpl &&
            (identical(other.fileId, fileId) || other.fileId == fileId) &&
            const DeepCollectionEquality().equals(other._pages, _pages) &&
            (identical(other.editionId, editionId) ||
                other.editionId == editionId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, fileId,
      const DeepCollectionEquality().hash(_pages), editionId);

  /// Create a copy of BJTDocument
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BJTDocumentImplCopyWith<_$BJTDocumentImpl> get copyWith =>
      __$$BJTDocumentImplCopyWithImpl<_$BJTDocumentImpl>(this, _$identity);
}

abstract class _BJTDocument extends BJTDocument {
  const factory _BJTDocument(
      {required final String fileId,
      final List<BJTPage> pages,
      final String editionId}) = _$BJTDocumentImpl;
  const _BJTDocument._() : super._();

  /// The unique identifier for this document (filename without extension)
  @override
  String get fileId;

  /// List of pages containing the text
  @override
  List<BJTPage> get pages;

  /// Edition identifier - always 'bjt' for this class
  @override
  String get editionId;

  /// Create a copy of BJTDocument
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BJTDocumentImplCopyWith<_$BJTDocumentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
