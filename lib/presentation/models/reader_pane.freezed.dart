// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_pane.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ReaderPane {
  /// Unique identifier for this pane instance
  /// Generated as UUID when creating a new pane
  String get paneId => throw _privateConstructorUsedError;

  /// Reference to the TextLayer being displayed
  /// Format: "{fileId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'dn1-pi-sinh', 'dn1-si-sinh', 'mn1-en-latn-sujato'
  String get layerId => throw _privateConstructorUsedError;

  /// Whether this pane is currently visible
  /// Hidden panes preserve their state but don't render
  bool get isVisible => throw _privateConstructorUsedError;

  /// Create a copy of ReaderPane
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReaderPaneCopyWith<ReaderPane> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReaderPaneCopyWith<$Res> {
  factory $ReaderPaneCopyWith(
          ReaderPane value, $Res Function(ReaderPane) then) =
      _$ReaderPaneCopyWithImpl<$Res, ReaderPane>;
  @useResult
  $Res call({String paneId, String layerId, bool isVisible});
}

/// @nodoc
class _$ReaderPaneCopyWithImpl<$Res, $Val extends ReaderPane>
    implements $ReaderPaneCopyWith<$Res> {
  _$ReaderPaneCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReaderPane
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paneId = null,
    Object? layerId = null,
    Object? isVisible = null,
  }) {
    return _then(_value.copyWith(
      paneId: null == paneId
          ? _value.paneId
          : paneId // ignore: cast_nullable_to_non_nullable
              as String,
      layerId: null == layerId
          ? _value.layerId
          : layerId // ignore: cast_nullable_to_non_nullable
              as String,
      isVisible: null == isVisible
          ? _value.isVisible
          : isVisible // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReaderPaneImplCopyWith<$Res>
    implements $ReaderPaneCopyWith<$Res> {
  factory _$$ReaderPaneImplCopyWith(
          _$ReaderPaneImpl value, $Res Function(_$ReaderPaneImpl) then) =
      __$$ReaderPaneImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String paneId, String layerId, bool isVisible});
}

/// @nodoc
class __$$ReaderPaneImplCopyWithImpl<$Res>
    extends _$ReaderPaneCopyWithImpl<$Res, _$ReaderPaneImpl>
    implements _$$ReaderPaneImplCopyWith<$Res> {
  __$$ReaderPaneImplCopyWithImpl(
      _$ReaderPaneImpl _value, $Res Function(_$ReaderPaneImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReaderPane
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? paneId = null,
    Object? layerId = null,
    Object? isVisible = null,
  }) {
    return _then(_$ReaderPaneImpl(
      paneId: null == paneId
          ? _value.paneId
          : paneId // ignore: cast_nullable_to_non_nullable
              as String,
      layerId: null == layerId
          ? _value.layerId
          : layerId // ignore: cast_nullable_to_non_nullable
              as String,
      isVisible: null == isVisible
          ? _value.isVisible
          : isVisible // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$ReaderPaneImpl implements _ReaderPane {
  const _$ReaderPaneImpl(
      {required this.paneId, required this.layerId, this.isVisible = true});

  /// Unique identifier for this pane instance
  /// Generated as UUID when creating a new pane
  @override
  final String paneId;

  /// Reference to the TextLayer being displayed
  /// Format: "{fileId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'dn1-pi-sinh', 'dn1-si-sinh', 'mn1-en-latn-sujato'
  @override
  final String layerId;

  /// Whether this pane is currently visible
  /// Hidden panes preserve their state but don't render
  @override
  @JsonKey()
  final bool isVisible;

  @override
  String toString() {
    return 'ReaderPane(paneId: $paneId, layerId: $layerId, isVisible: $isVisible)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReaderPaneImpl &&
            (identical(other.paneId, paneId) || other.paneId == paneId) &&
            (identical(other.layerId, layerId) || other.layerId == layerId) &&
            (identical(other.isVisible, isVisible) ||
                other.isVisible == isVisible));
  }

  @override
  int get hashCode => Object.hash(runtimeType, paneId, layerId, isVisible);

  /// Create a copy of ReaderPane
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReaderPaneImplCopyWith<_$ReaderPaneImpl> get copyWith =>
      __$$ReaderPaneImplCopyWithImpl<_$ReaderPaneImpl>(this, _$identity);
}

abstract class _ReaderPane implements ReaderPane {
  const factory _ReaderPane(
      {required final String paneId,
      required final String layerId,
      final bool isVisible}) = _$ReaderPaneImpl;

  /// Unique identifier for this pane instance
  /// Generated as UUID when creating a new pane
  @override
  String get paneId;

  /// Reference to the TextLayer being displayed
  /// Format: "{fileId}-{languageCode}-{scriptCode}[-{translator}]"
  /// Examples: 'dn1-pi-sinh', 'dn1-si-sinh', 'mn1-en-latn-sujato'
  @override
  String get layerId;

  /// Whether this pane is currently visible
  /// Hidden panes preserve their state but don't render
  @override
  bool get isVisible;

  /// Create a copy of ReaderPane
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReaderPaneImplCopyWith<_$ReaderPaneImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
