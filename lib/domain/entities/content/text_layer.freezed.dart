// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'text_layer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TextLayer {
  /// Unique identifier for this layer
  /// Format: "{editionId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'bjt-pi-sinh', 'bjt-pi-latn', 'bjt-si-sinh', 'sc-en-latn-sujato'
  String get layerId => throw _privateConstructorUsedError;

  /// Edition this layer belongs to ('bjt', 'suttacentral', 'pts')
  String get editionId => throw _privateConstructorUsedError;

  /// ISO 639-1 language code ('pi', 'si', 'en', etc.)
  String get languageCode => throw _privateConstructorUsedError;

  /// ISO 15924 script code
  /// - 'sinh' = Sinhala script (සද්ධම්මං)
  /// - 'latn' = Latin/Roman script (Saddhammaṁ)
  /// - 'thai' = Thai script (สัทธัมมัง)
  /// - 'deva' = Devanagari script (सद्धम्मं)
  /// - 'mymr' = Myanmar/Burmese script
  String get scriptCode => throw _privateConstructorUsedError;

  /// Translator name (optional, primarily for SuttaCentral)
  /// Examples: 'Bhikkhu Sujato', 'Bhikkhu Bodhi'
  String? get translator => throw _privateConstructorUsedError;

  /// Flattened list of entries across all pages
  /// This removes the page structure to enable easier cross-edition alignment
  List<Entry> get segments => throw _privateConstructorUsedError;

  /// Create a copy of TextLayer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TextLayerCopyWith<TextLayer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TextLayerCopyWith<$Res> {
  factory $TextLayerCopyWith(TextLayer value, $Res Function(TextLayer) then) =
      _$TextLayerCopyWithImpl<$Res, TextLayer>;
  @useResult
  $Res call(
      {String layerId,
      String editionId,
      String languageCode,
      String scriptCode,
      String? translator,
      List<Entry> segments});
}

/// @nodoc
class _$TextLayerCopyWithImpl<$Res, $Val extends TextLayer>
    implements $TextLayerCopyWith<$Res> {
  _$TextLayerCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TextLayer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? layerId = null,
    Object? editionId = null,
    Object? languageCode = null,
    Object? scriptCode = null,
    Object? translator = freezed,
    Object? segments = null,
  }) {
    return _then(_value.copyWith(
      layerId: null == layerId
          ? _value.layerId
          : layerId // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      scriptCode: null == scriptCode
          ? _value.scriptCode
          : scriptCode // ignore: cast_nullable_to_non_nullable
              as String,
      translator: freezed == translator
          ? _value.translator
          : translator // ignore: cast_nullable_to_non_nullable
              as String?,
      segments: null == segments
          ? _value.segments
          : segments // ignore: cast_nullable_to_non_nullable
              as List<Entry>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TextLayerImplCopyWith<$Res>
    implements $TextLayerCopyWith<$Res> {
  factory _$$TextLayerImplCopyWith(
          _$TextLayerImpl value, $Res Function(_$TextLayerImpl) then) =
      __$$TextLayerImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String layerId,
      String editionId,
      String languageCode,
      String scriptCode,
      String? translator,
      List<Entry> segments});
}

/// @nodoc
class __$$TextLayerImplCopyWithImpl<$Res>
    extends _$TextLayerCopyWithImpl<$Res, _$TextLayerImpl>
    implements _$$TextLayerImplCopyWith<$Res> {
  __$$TextLayerImplCopyWithImpl(
      _$TextLayerImpl _value, $Res Function(_$TextLayerImpl) _then)
      : super(_value, _then);

  /// Create a copy of TextLayer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? layerId = null,
    Object? editionId = null,
    Object? languageCode = null,
    Object? scriptCode = null,
    Object? translator = freezed,
    Object? segments = null,
  }) {
    return _then(_$TextLayerImpl(
      layerId: null == layerId
          ? _value.layerId
          : layerId // ignore: cast_nullable_to_non_nullable
              as String,
      editionId: null == editionId
          ? _value.editionId
          : editionId // ignore: cast_nullable_to_non_nullable
              as String,
      languageCode: null == languageCode
          ? _value.languageCode
          : languageCode // ignore: cast_nullable_to_non_nullable
              as String,
      scriptCode: null == scriptCode
          ? _value.scriptCode
          : scriptCode // ignore: cast_nullable_to_non_nullable
              as String,
      translator: freezed == translator
          ? _value.translator
          : translator // ignore: cast_nullable_to_non_nullable
              as String?,
      segments: null == segments
          ? _value._segments
          : segments // ignore: cast_nullable_to_non_nullable
              as List<Entry>,
    ));
  }
}

/// @nodoc

class _$TextLayerImpl extends _TextLayer {
  const _$TextLayerImpl(
      {required this.layerId,
      required this.editionId,
      required this.languageCode,
      required this.scriptCode,
      this.translator,
      final List<Entry> segments = const []})
      : _segments = segments,
        super._();

  /// Unique identifier for this layer
  /// Format: "{editionId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'bjt-pi-sinh', 'bjt-pi-latn', 'bjt-si-sinh', 'sc-en-latn-sujato'
  @override
  final String layerId;

  /// Edition this layer belongs to ('bjt', 'suttacentral', 'pts')
  @override
  final String editionId;

  /// ISO 639-1 language code ('pi', 'si', 'en', etc.)
  @override
  final String languageCode;

  /// ISO 15924 script code
  /// - 'sinh' = Sinhala script (සද්ධම්මං)
  /// - 'latn' = Latin/Roman script (Saddhammaṁ)
  /// - 'thai' = Thai script (สัทธัมมัง)
  /// - 'deva' = Devanagari script (सद्धम्मं)
  /// - 'mymr' = Myanmar/Burmese script
  @override
  final String scriptCode;

  /// Translator name (optional, primarily for SuttaCentral)
  /// Examples: 'Bhikkhu Sujato', 'Bhikkhu Bodhi'
  @override
  final String? translator;

  /// Flattened list of entries across all pages
  /// This removes the page structure to enable easier cross-edition alignment
  final List<Entry> _segments;

  /// Flattened list of entries across all pages
  /// This removes the page structure to enable easier cross-edition alignment
  @override
  @JsonKey()
  List<Entry> get segments {
    if (_segments is EqualUnmodifiableListView) return _segments;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_segments);
  }

  @override
  String toString() {
    return 'TextLayer(layerId: $layerId, editionId: $editionId, languageCode: $languageCode, scriptCode: $scriptCode, translator: $translator, segments: $segments)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TextLayerImpl &&
            (identical(other.layerId, layerId) || other.layerId == layerId) &&
            (identical(other.editionId, editionId) ||
                other.editionId == editionId) &&
            (identical(other.languageCode, languageCode) ||
                other.languageCode == languageCode) &&
            (identical(other.scriptCode, scriptCode) ||
                other.scriptCode == scriptCode) &&
            (identical(other.translator, translator) ||
                other.translator == translator) &&
            const DeepCollectionEquality().equals(other._segments, _segments));
  }

  @override
  int get hashCode => Object.hash(runtimeType, layerId, editionId, languageCode,
      scriptCode, translator, const DeepCollectionEquality().hash(_segments));

  /// Create a copy of TextLayer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TextLayerImplCopyWith<_$TextLayerImpl> get copyWith =>
      __$$TextLayerImplCopyWithImpl<_$TextLayerImpl>(this, _$identity);
}

abstract class _TextLayer extends TextLayer {
  const factory _TextLayer(
      {required final String layerId,
      required final String editionId,
      required final String languageCode,
      required final String scriptCode,
      final String? translator,
      final List<Entry> segments}) = _$TextLayerImpl;
  const _TextLayer._() : super._();

  /// Unique identifier for this layer
  /// Format: "{editionId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'bjt-pi-sinh', 'bjt-pi-latn', 'bjt-si-sinh', 'sc-en-latn-sujato'
  @override
  String get layerId;

  /// Edition this layer belongs to ('bjt', 'suttacentral', 'pts')
  @override
  String get editionId;

  /// ISO 639-1 language code ('pi', 'si', 'en', etc.)
  @override
  String get languageCode;

  /// ISO 15924 script code
  /// - 'sinh' = Sinhala script (සද්ධම්මං)
  /// - 'latn' = Latin/Roman script (Saddhammaṁ)
  /// - 'thai' = Thai script (สัทธัมมัง)
  /// - 'deva' = Devanagari script (सद्धम्मं)
  /// - 'mymr' = Myanmar/Burmese script
  @override
  String get scriptCode;

  /// Translator name (optional, primarily for SuttaCentral)
  /// Examples: 'Bhikkhu Sujato', 'Bhikkhu Bodhi'
  @override
  String? get translator;

  /// Flattened list of entries across all pages
  /// This removes the page structure to enable easier cross-edition alignment
  @override
  List<Entry> get segments;

  /// Create a copy of TextLayer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TextLayerImplCopyWith<_$TextLayerImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
