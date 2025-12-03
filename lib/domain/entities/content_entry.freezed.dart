// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'content_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ContentEntry {
  /// The type of this content entry (paragraph, heading, centered, etc.)
  EntryType get entryType => throw _privateConstructorUsedError;

  /// The raw text content with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  String get rawTextContent => throw _privateConstructorUsedError;

  /// Optional reference to a footnote
  String? get footnoteReference => throw _privateConstructorUsedError;

  /// Create a copy of ContentEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ContentEntryCopyWith<ContentEntry> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ContentEntryCopyWith<$Res> {
  factory $ContentEntryCopyWith(
          ContentEntry value, $Res Function(ContentEntry) then) =
      _$ContentEntryCopyWithImpl<$Res, ContentEntry>;
  @useResult
  $Res call(
      {EntryType entryType, String rawTextContent, String? footnoteReference});
}

/// @nodoc
class _$ContentEntryCopyWithImpl<$Res, $Val extends ContentEntry>
    implements $ContentEntryCopyWith<$Res> {
  _$ContentEntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ContentEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryType = null,
    Object? rawTextContent = null,
    Object? footnoteReference = freezed,
  }) {
    return _then(_value.copyWith(
      entryType: null == entryType
          ? _value.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as EntryType,
      rawTextContent: null == rawTextContent
          ? _value.rawTextContent
          : rawTextContent // ignore: cast_nullable_to_non_nullable
              as String,
      footnoteReference: freezed == footnoteReference
          ? _value.footnoteReference
          : footnoteReference // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ContentEntryImplCopyWith<$Res>
    implements $ContentEntryCopyWith<$Res> {
  factory _$$ContentEntryImplCopyWith(
          _$ContentEntryImpl value, $Res Function(_$ContentEntryImpl) then) =
      __$$ContentEntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {EntryType entryType, String rawTextContent, String? footnoteReference});
}

/// @nodoc
class __$$ContentEntryImplCopyWithImpl<$Res>
    extends _$ContentEntryCopyWithImpl<$Res, _$ContentEntryImpl>
    implements _$$ContentEntryImplCopyWith<$Res> {
  __$$ContentEntryImplCopyWithImpl(
      _$ContentEntryImpl _value, $Res Function(_$ContentEntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of ContentEntry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryType = null,
    Object? rawTextContent = null,
    Object? footnoteReference = freezed,
  }) {
    return _then(_$ContentEntryImpl(
      entryType: null == entryType
          ? _value.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as EntryType,
      rawTextContent: null == rawTextContent
          ? _value.rawTextContent
          : rawTextContent // ignore: cast_nullable_to_non_nullable
              as String,
      footnoteReference: freezed == footnoteReference
          ? _value.footnoteReference
          : footnoteReference // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$ContentEntryImpl extends _ContentEntry {
  const _$ContentEntryImpl(
      {required this.entryType,
      required this.rawTextContent,
      this.footnoteReference})
      : super._();

  /// The type of this content entry (paragraph, heading, centered, etc.)
  @override
  final EntryType entryType;

  /// The raw text content with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  @override
  final String rawTextContent;

  /// Optional reference to a footnote
  @override
  final String? footnoteReference;

  @override
  String toString() {
    return 'ContentEntry(entryType: $entryType, rawTextContent: $rawTextContent, footnoteReference: $footnoteReference)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ContentEntryImpl &&
            (identical(other.entryType, entryType) ||
                other.entryType == entryType) &&
            (identical(other.rawTextContent, rawTextContent) ||
                other.rawTextContent == rawTextContent) &&
            (identical(other.footnoteReference, footnoteReference) ||
                other.footnoteReference == footnoteReference));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, entryType, rawTextContent, footnoteReference);

  /// Create a copy of ContentEntry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ContentEntryImplCopyWith<_$ContentEntryImpl> get copyWith =>
      __$$ContentEntryImplCopyWithImpl<_$ContentEntryImpl>(this, _$identity);
}

abstract class _ContentEntry extends ContentEntry {
  const factory _ContentEntry(
      {required final EntryType entryType,
      required final String rawTextContent,
      final String? footnoteReference}) = _$ContentEntryImpl;
  const _ContentEntry._() : super._();

  /// The type of this content entry (paragraph, heading, centered, etc.)
  @override
  EntryType get entryType;

  /// The raw text content with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  @override
  String get rawTextContent;

  /// Optional reference to a footnote
  @override
  String? get footnoteReference;

  /// Create a copy of ContentEntry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ContentEntryImplCopyWith<_$ContentEntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
