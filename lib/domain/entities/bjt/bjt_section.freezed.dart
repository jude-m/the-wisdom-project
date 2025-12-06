// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bjt_section.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$BJTSection {
  /// ISO 639-1 language code ('pi' for Pali, 'si' for Sinhala)
  String get languageCode => throw _privateConstructorUsedError;

  /// List of entries in this section
  List<Entry> get entries => throw _privateConstructorUsedError;

  /// List of footnotes for this section
  List<String> get footnotes => throw _privateConstructorUsedError;

  /// Create a copy of BJTSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $BJTSectionCopyWith<BJTSection> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $BJTSectionCopyWith<$Res> {
  factory $BJTSectionCopyWith(
          BJTSection value, $Res Function(BJTSection) then) =
      _$BJTSectionCopyWithImpl<$Res, BJTSection>;
  @useResult
  $Res call({String languageCode, List<Entry> entries, List<String> footnotes});
}

/// @nodoc
class _$BJTSectionCopyWithImpl<$Res, $Val extends BJTSection>
    implements $BJTSectionCopyWith<$Res> {
  _$BJTSectionCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of BJTSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageCode = null,
    Object? entries = null,
    Object? footnotes = null,
  }) {
    return _then(_value.copyWith(
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _value.entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<Entry>,
      footnotes: null == footnotes
          ? _value.footnotes
          : footnotes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$BJTSectionImplCopyWith<$Res>
    implements $BJTSectionCopyWith<$Res> {
  factory _$$BJTSectionImplCopyWith(
          _$BJTSectionImpl value, $Res Function(_$BJTSectionImpl) then) =
      __$$BJTSectionImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String languageCode, List<Entry> entries, List<String> footnotes});
}

/// @nodoc
class __$$BJTSectionImplCopyWithImpl<$Res>
    extends _$BJTSectionCopyWithImpl<$Res, _$BJTSectionImpl>
    implements _$$BJTSectionImplCopyWith<$Res> {
  __$$BJTSectionImplCopyWithImpl(
      _$BJTSectionImpl _value, $Res Function(_$BJTSectionImpl) _then)
      : super(_value, _then);

  /// Create a copy of BJTSection
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? languageCode = null,
    Object? entries = null,
    Object? footnotes = null,
  }) {
    return _then(_$BJTSectionImpl(
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      entries: null == entries
          ? _value._entries
          : entries // ignore: cast_nullable_to_non_nullable
              as List<Entry>,
      footnotes: null == footnotes
          ? _value._footnotes
          : footnotes // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

/// @nodoc

class _$BJTSectionImpl extends _BJTSection {
  const _$BJTSectionImpl(
      {required this.languageCode,
      final List<Entry> entries = const [],
      final List<String> footnotes = const []})
      : _entries = entries,
        _footnotes = footnotes,
        super._();

  /// ISO 639-1 language code ('pi' for Pali, 'si' for Sinhala)
  @override
  final String languageCode;

  /// List of entries in this section
  final List<Entry> _entries;

  /// List of entries in this section
  @override
  @JsonKey()
  List<Entry> get entries {
    if (_entries is EqualUnmodifiableListView) return _entries;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_entries);
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
    return 'BJTSection(languageCode: $languageCode, entries: $entries, footnotes: $footnotes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$BJTSectionImpl &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode) &&
            const DeepCollectionEquality().equals(other._entries, _entries) &&
            const DeepCollectionEquality()
                .equals(other._footnotes, _footnotes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      languageCode,
      const DeepCollectionEquality().hash(_entries),
      const DeepCollectionEquality().hash(_footnotes));

  /// Create a copy of BJTSection
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$BJTSectionImplCopyWith<_$BJTSectionImpl> get copyWith =>
      __$$BJTSectionImplCopyWithImpl<_$BJTSectionImpl>(this, _$identity);
}

abstract class _BJTSection extends BJTSection {
  const factory _BJTSection(
      {required final String languageCode,
      final List<Entry> entries,
      final List<String> footnotes}) = _$BJTSectionImpl;
  const _BJTSection._() : super._();

  /// ISO 639-1 language code ('pi' for Pali, 'si' for Sinhala)
  @override
  String get languageCode;

  /// List of entries in this section
  @override
  List<Entry> get entries;

  /// List of footnotes for this section
  @override
  List<String> get footnotes;

  /// Create a copy of BJTSection
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$BJTSectionImplCopyWith<_$BJTSectionImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
