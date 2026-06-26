// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'citation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

Citation _$CitationFromJson(Map<String, dynamic> json) {
  return _Citation.fromJson(json);
}

/// @nodoc
mixin _$Citation {
  /// SuttaCentral uid, e.g. "sn15.3" or "pli-tv-bu-vb-np18".
  String get uid => throw _privateConstructorUsedError;

  /// Human-readable reference shown to the user, e.g. "SN 15.3".
  String get ref => throw _privateConstructorUsedError;

  /// "canon" today; "note" reserved for Sujato's notes (design §5.2).
  /// Kept from day one so adding notes later needs no contract change.
  String get kind => throw _privateConstructorUsedError;

  /// English source span used to ground this point (doubles as the
  /// verification preview the deep link would open).
  String? get snippet => throw _privateConstructorUsedError;

  /// In-app deep link. Null until the SuttaCentral→BJT resolver lands
  /// (see the resolver plan, Part D). Not rendered as a tappable link in v1.
  String? get deeplink => throw _privateConstructorUsedError;

  /// Serializes this Citation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CitationCopyWith<Citation> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CitationCopyWith<$Res> {
  factory $CitationCopyWith(Citation value, $Res Function(Citation) then) =
      _$CitationCopyWithImpl<$Res, Citation>;
  @useResult
  $Res call(
      {String uid, String ref, String kind, String? snippet, String? deeplink});
}

/// @nodoc
class _$CitationCopyWithImpl<$Res, $Val extends Citation>
    implements $CitationCopyWith<$Res> {
  _$CitationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? ref = null,
    Object? kind = null,
    Object? snippet = freezed,
    Object? deeplink = freezed,
  }) {
    return _then(_value.copyWith(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      ref: null == ref
          ? _value.ref
          : ref // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String,
      snippet: freezed == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String?,
      deeplink: freezed == deeplink
          ? _value.deeplink
          : deeplink // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CitationImplCopyWith<$Res>
    implements $CitationCopyWith<$Res> {
  factory _$$CitationImplCopyWith(
          _$CitationImpl value, $Res Function(_$CitationImpl) then) =
      __$$CitationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String uid, String ref, String kind, String? snippet, String? deeplink});
}

/// @nodoc
class __$$CitationImplCopyWithImpl<$Res>
    extends _$CitationCopyWithImpl<$Res, _$CitationImpl>
    implements _$$CitationImplCopyWith<$Res> {
  __$$CitationImplCopyWithImpl(
      _$CitationImpl _value, $Res Function(_$CitationImpl) _then)
      : super(_value, _then);

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? uid = null,
    Object? ref = null,
    Object? kind = null,
    Object? snippet = freezed,
    Object? deeplink = freezed,
  }) {
    return _then(_$CitationImpl(
      uid: null == uid
          ? _value.uid
          : uid // ignore: cast_nullable_to_non_nullable
              as String,
      ref: null == ref
          ? _value.ref
          : ref // ignore: cast_nullable_to_non_nullable
              as String,
      kind: null == kind
          ? _value.kind
          : kind // ignore: cast_nullable_to_non_nullable
              as String,
      snippet: freezed == snippet
          ? _value.snippet
          : snippet // ignore: cast_nullable_to_non_nullable
              as String?,
      deeplink: freezed == deeplink
          ? _value.deeplink
          : deeplink // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CitationImpl implements _Citation {
  const _$CitationImpl(
      {required this.uid,
      required this.ref,
      this.kind = 'canon',
      this.snippet,
      this.deeplink});

  factory _$CitationImpl.fromJson(Map<String, dynamic> json) =>
      _$$CitationImplFromJson(json);

  /// SuttaCentral uid, e.g. "sn15.3" or "pli-tv-bu-vb-np18".
  @override
  final String uid;

  /// Human-readable reference shown to the user, e.g. "SN 15.3".
  @override
  final String ref;

  /// "canon" today; "note" reserved for Sujato's notes (design §5.2).
  /// Kept from day one so adding notes later needs no contract change.
  @override
  @JsonKey()
  final String kind;

  /// English source span used to ground this point (doubles as the
  /// verification preview the deep link would open).
  @override
  final String? snippet;

  /// In-app deep link. Null until the SuttaCentral→BJT resolver lands
  /// (see the resolver plan, Part D). Not rendered as a tappable link in v1.
  @override
  final String? deeplink;

  @override
  String toString() {
    return 'Citation(uid: $uid, ref: $ref, kind: $kind, snippet: $snippet, deeplink: $deeplink)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CitationImpl &&
            (identical(other.uid, uid) || other.uid == uid) &&
            (identical(other.ref, ref) || other.ref == ref) &&
            (identical(other.kind, kind) || other.kind == kind) &&
            (identical(other.snippet, snippet) || other.snippet == snippet) &&
            (identical(other.deeplink, deeplink) ||
                other.deeplink == deeplink));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, uid, ref, kind, snippet, deeplink);

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CitationImplCopyWith<_$CitationImpl> get copyWith =>
      __$$CitationImplCopyWithImpl<_$CitationImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CitationImplToJson(
      this,
    );
  }
}

abstract class _Citation implements Citation {
  const factory _Citation(
      {required final String uid,
      required final String ref,
      final String kind,
      final String? snippet,
      final String? deeplink}) = _$CitationImpl;

  factory _Citation.fromJson(Map<String, dynamic> json) =
      _$CitationImpl.fromJson;

  /// SuttaCentral uid, e.g. "sn15.3" or "pli-tv-bu-vb-np18".
  @override
  String get uid;

  /// Human-readable reference shown to the user, e.g. "SN 15.3".
  @override
  String get ref;

  /// "canon" today; "note" reserved for Sujato's notes (design §5.2).
  /// Kept from day one so adding notes later needs no contract change.
  @override
  String get kind;

  /// English source span used to ground this point (doubles as the
  /// verification preview the deep link would open).
  @override
  String? get snippet;

  /// In-app deep link. Null until the SuttaCentral→BJT resolver lands
  /// (see the resolver plan, Part D). Not rendered as a tappable link in v1.
  @override
  String? get deeplink;

  /// Create a copy of Citation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CitationImplCopyWith<_$CitationImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
