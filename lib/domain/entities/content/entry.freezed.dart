// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$Entry {
  /// The type of this entry (paragraph, heading, centered, etc.)
  EntryType get entryType => throw _privateConstructorUsedError;

  /// The raw text with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  String get rawText => throw _privateConstructorUsedError;

  /// Unique segment identifier for cross-edition alignment
  /// Generated at runtime for BJT (e.g., "dn-1:bjt:0")
  /// Loaded from JSON for SuttaCentral (e.g., "dn1:1.1")
  String? get segmentId => throw _privateConstructorUsedError;

  /// Optional reference to a footnote
  String? get footnoteReference => throw _privateConstructorUsedError;

  /// Create a copy of Entry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $EntryCopyWith<Entry> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $EntryCopyWith<$Res> {
  factory $EntryCopyWith(Entry value, $Res Function(Entry) then) =
      _$EntryCopyWithImpl<$Res, Entry>;
  @useResult
  $Res call(
      {EntryType entryType,
      String rawText,
      String? segmentId,
      String? footnoteReference});
}

/// @nodoc
class _$EntryCopyWithImpl<$Res, $Val extends Entry>
    implements $EntryCopyWith<$Res> {
  _$EntryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Entry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryType = null,
    Object? rawText = null,
    Object? segmentId = freezed,
    Object? footnoteReference = freezed,
  }) {
    return _then(_value.copyWith(
      entryType: null == entryType
          ? _value.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as EntryType,
      rawText: null == rawText
          ? _value.rawText
          : rawText // ignore: cast_nullable_to_non_nullable
              as String,
      segmentId: freezed == segmentId
          ? _value.segmentId
          : segmentId // ignore: cast_nullable_to_non_nullable
              as String?,
      footnoteReference: freezed == footnoteReference
          ? _value.footnoteReference
          : footnoteReference // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$EntryImplCopyWith<$Res> implements $EntryCopyWith<$Res> {
  factory _$$EntryImplCopyWith(
          _$EntryImpl value, $Res Function(_$EntryImpl) then) =
      __$$EntryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {EntryType entryType,
      String rawText,
      String? segmentId,
      String? footnoteReference});
}

/// @nodoc
class __$$EntryImplCopyWithImpl<$Res>
    extends _$EntryCopyWithImpl<$Res, _$EntryImpl>
    implements _$$EntryImplCopyWith<$Res> {
  __$$EntryImplCopyWithImpl(
      _$EntryImpl _value, $Res Function(_$EntryImpl) _then)
      : super(_value, _then);

  /// Create a copy of Entry
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entryType = null,
    Object? rawText = null,
    Object? segmentId = freezed,
    Object? footnoteReference = freezed,
  }) {
    return _then(_$EntryImpl(
      entryType: null == entryType
          ? _value.entryType
          : entryType // ignore: cast_nullable_to_non_nullable
              as EntryType,
      rawText: null == rawText
          ? _value.rawText
          : rawText // ignore: cast_nullable_to_non_nullable
              as String,
      segmentId: freezed == segmentId
          ? _value.segmentId
          : segmentId // ignore: cast_nullable_to_non_nullable
              as String?,
      footnoteReference: freezed == footnoteReference
          ? _value.footnoteReference
          : footnoteReference // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$EntryImpl extends _Entry {
  const _$EntryImpl(
      {required this.entryType,
      required this.rawText,
      this.segmentId,
      this.footnoteReference})
      : super._();

  /// The type of this entry (paragraph, heading, centered, etc.)
  @override
  final EntryType entryType;

  /// The raw text with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  @override
  final String rawText;

  /// Unique segment identifier for cross-edition alignment
  /// Generated at runtime for BJT (e.g., "dn-1:bjt:0")
  /// Loaded from JSON for SuttaCentral (e.g., "dn1:1.1")
  @override
  final String? segmentId;

  /// Optional reference to a footnote
  @override
  final String? footnoteReference;

  @override
  String toString() {
    return 'Entry(entryType: $entryType, rawText: $rawText, segmentId: $segmentId, footnoteReference: $footnoteReference)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$EntryImpl &&
            (identical(other.entryType, entryType) ||
                other.entryType == entryType) &&
            (identical(other.rawText, rawText) || other.rawText == rawText) &&
            (identical(other.segmentId, segmentId) ||
                other.segmentId == segmentId) &&
            (identical(other.footnoteReference, footnoteReference) ||
                other.footnoteReference == footnoteReference));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, entryType, rawText, segmentId, footnoteReference);

  /// Create a copy of Entry
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$EntryImplCopyWith<_$EntryImpl> get copyWith =>
      __$$EntryImplCopyWithImpl<_$EntryImpl>(this, _$identity);
}

abstract class _Entry extends Entry {
  const factory _Entry(
      {required final EntryType entryType,
      required final String rawText,
      final String? segmentId,
      final String? footnoteReference}) = _$EntryImpl;
  const _Entry._() : super._();

  /// The type of this entry (paragraph, heading, centered, etc.)
  @override
  EntryType get entryType;

  /// The raw text with formatting markers
  /// Examples of markers: **bold**, __underline__, {footnote}
  @override
  String get rawText;

  /// Unique segment identifier for cross-edition alignment
  /// Generated at runtime for BJT (e.g., "dn-1:bjt:0")
  /// Loaded from JSON for SuttaCentral (e.g., "dn1:1.1")
  @override
  String? get segmentId;

  /// Optional reference to a footnote
  @override
  String? get footnoteReference;

  /// Create a copy of Entry
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$EntryImplCopyWith<_$EntryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
