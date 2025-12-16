// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_tab.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ReaderTab {
  /// Short label for tab display (truncated if needed)
  String get label => throw _privateConstructorUsedError;

  /// Full name for tooltip or expanded view
  String get fullName => throw _privateConstructorUsedError;

  /// ID of the content file currently loaded in this tab
  String? get contentFileId => throw _privateConstructorUsedError;

  /// Current page index within the content file
  int get pageIndex => throw _privateConstructorUsedError;

  /// Start of loaded page range (for pagination)
  int get pageStart => throw _privateConstructorUsedError;

  /// End of loaded page range (for pagination, exclusive)
  int get pageEnd => throw _privateConstructorUsedError;

  /// Entry index to start from on the first visible page
  /// This allows opening a sutta mid-page without showing earlier entries
  int get entryStart => throw _privateConstructorUsedError;

  /// Reference to the tree node key for navigation sync
  String? get nodeKey => throw _privateConstructorUsedError;

  /// Pali name of the node for reference
  String? get paliName => throw _privateConstructorUsedError;

  /// Sinhala name of the node for reference
  String? get sinhalaName => throw _privateConstructorUsedError;

  /// Universal text identifier (e.g., 'dn1', 'mn100', 'sn1-1')
  /// This is edition-agnostic and used for cross-edition alignment
  /// Nullable for backward compatibility - derived from contentFileId if needed
  String? get textId => throw _privateConstructorUsedError;

  /// List of panes to display in this tab
  /// Each pane shows one TextLayer (edition + language + script combination)
  /// Empty list means using legacy dual-pane mode (Pali + Sinhala)
  /// Nullable for backward compatibility
  List<ReaderPane> get panes => throw _privateConstructorUsedError;

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ReaderTabCopyWith<ReaderTab> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ReaderTabCopyWith<$Res> {
  factory $ReaderTabCopyWith(ReaderTab value, $Res Function(ReaderTab) then) =
      _$ReaderTabCopyWithImpl<$Res, ReaderTab>;
  @useResult
  $Res call(
      {String label,
      String fullName,
      String? contentFileId,
      int pageIndex,
      int pageStart,
      int pageEnd,
      int entryStart,
      String? nodeKey,
      String? paliName,
      String? sinhalaName,
      String? textId,
      List<ReaderPane> panes});
}

/// @nodoc
class _$ReaderTabCopyWithImpl<$Res, $Val extends ReaderTab>
    implements $ReaderTabCopyWith<$Res> {
  _$ReaderTabCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? fullName = null,
    Object? contentFileId = freezed,
    Object? pageIndex = null,
    Object? pageStart = null,
    Object? pageEnd = null,
    Object? entryStart = null,
    Object? nodeKey = freezed,
    Object? paliName = freezed,
    Object? sinhalaName = freezed,
    Object? textId = freezed,
    Object? panes = null,
  }) {
    return _then(_value.copyWith(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      fullName: null == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String,
      contentFileId: freezed == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String?,
      pageIndex: null == pageIndex
          ? _value.pageIndex
          : pageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      pageStart: null == pageStart
          ? _value.pageStart
          : pageStart // ignore: cast_nullable_to_non_nullable
              as int,
      pageEnd: null == pageEnd
          ? _value.pageEnd
          : pageEnd // ignore: cast_nullable_to_non_nullable
              as int,
      entryStart: null == entryStart
          ? _value.entryStart
          : entryStart // ignore: cast_nullable_to_non_nullable
              as int,
      nodeKey: freezed == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      paliName: freezed == paliName
          ? _value.paliName
          : paliName // ignore: cast_nullable_to_non_nullable
              as String?,
      sinhalaName: freezed == sinhalaName
          ? _value.sinhalaName
          : sinhalaName // ignore: cast_nullable_to_non_nullable
              as String?,
      textId: freezed == textId
          ? _value.textId
          : textId // ignore: cast_nullable_to_non_nullable
              as String?,
      panes: null == panes
          ? _value.panes
          : panes // ignore: cast_nullable_to_non_nullable
              as List<ReaderPane>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ReaderTabImplCopyWith<$Res>
    implements $ReaderTabCopyWith<$Res> {
  factory _$$ReaderTabImplCopyWith(
          _$ReaderTabImpl value, $Res Function(_$ReaderTabImpl) then) =
      __$$ReaderTabImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String label,
      String fullName,
      String? contentFileId,
      int pageIndex,
      int pageStart,
      int pageEnd,
      int entryStart,
      String? nodeKey,
      String? paliName,
      String? sinhalaName,
      String? textId,
      List<ReaderPane> panes});
}

/// @nodoc
class __$$ReaderTabImplCopyWithImpl<$Res>
    extends _$ReaderTabCopyWithImpl<$Res, _$ReaderTabImpl>
    implements _$$ReaderTabImplCopyWith<$Res> {
  __$$ReaderTabImplCopyWithImpl(
      _$ReaderTabImpl _value, $Res Function(_$ReaderTabImpl) _then)
      : super(_value, _then);

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? label = null,
    Object? fullName = null,
    Object? contentFileId = freezed,
    Object? pageIndex = null,
    Object? pageStart = null,
    Object? pageEnd = null,
    Object? entryStart = null,
    Object? nodeKey = freezed,
    Object? paliName = freezed,
    Object? sinhalaName = freezed,
    Object? textId = freezed,
    Object? panes = null,
  }) {
    return _then(_$ReaderTabImpl(
      label: null == label
          ? _value.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      fullName: null == fullName
          ? _value.fullName
          : fullName // ignore: cast_nullable_to_non_nullable
              as String,
      contentFileId: freezed == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String?,
      pageIndex: null == pageIndex
          ? _value.pageIndex
          : pageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      pageStart: null == pageStart
          ? _value.pageStart
          : pageStart // ignore: cast_nullable_to_non_nullable
              as int,
      pageEnd: null == pageEnd
          ? _value.pageEnd
          : pageEnd // ignore: cast_nullable_to_non_nullable
              as int,
      entryStart: null == entryStart
          ? _value.entryStart
          : entryStart // ignore: cast_nullable_to_non_nullable
              as int,
      nodeKey: freezed == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      paliName: freezed == paliName
          ? _value.paliName
          : paliName // ignore: cast_nullable_to_non_nullable
              as String?,
      sinhalaName: freezed == sinhalaName
          ? _value.sinhalaName
          : sinhalaName // ignore: cast_nullable_to_non_nullable
              as String?,
      textId: freezed == textId
          ? _value.textId
          : textId // ignore: cast_nullable_to_non_nullable
              as String?,
      panes: null == panes
          ? _value._panes
          : panes // ignore: cast_nullable_to_non_nullable
              as List<ReaderPane>,
    ));
  }
}

/// @nodoc

class _$ReaderTabImpl extends _ReaderTab {
  const _$ReaderTabImpl(
      {required this.label,
      required this.fullName,
      this.contentFileId,
      this.pageIndex = 0,
      this.pageStart = 0,
      this.pageEnd = 1,
      this.entryStart = 0,
      this.nodeKey,
      this.paliName,
      this.sinhalaName,
      this.textId,
      final List<ReaderPane> panes = const []})
      : _panes = panes,
        super._();

  /// Short label for tab display (truncated if needed)
  @override
  final String label;

  /// Full name for tooltip or expanded view
  @override
  final String fullName;

  /// ID of the content file currently loaded in this tab
  @override
  final String? contentFileId;

  /// Current page index within the content file
  @override
  @JsonKey()
  final int pageIndex;

  /// Start of loaded page range (for pagination)
  @override
  @JsonKey()
  final int pageStart;

  /// End of loaded page range (for pagination, exclusive)
  @override
  @JsonKey()
  final int pageEnd;

  /// Entry index to start from on the first visible page
  /// This allows opening a sutta mid-page without showing earlier entries
  @override
  @JsonKey()
  final int entryStart;

  /// Reference to the tree node key for navigation sync
  @override
  final String? nodeKey;

  /// Pali name of the node for reference
  @override
  final String? paliName;

  /// Sinhala name of the node for reference
  @override
  final String? sinhalaName;

  /// Universal text identifier (e.g., 'dn1', 'mn100', 'sn1-1')
  /// This is edition-agnostic and used for cross-edition alignment
  /// Nullable for backward compatibility - derived from contentFileId if needed
  @override
  final String? textId;

  /// List of panes to display in this tab
  /// Each pane shows one TextLayer (edition + language + script combination)
  /// Empty list means using legacy dual-pane mode (Pali + Sinhala)
  /// Nullable for backward compatibility
  final List<ReaderPane> _panes;

  /// List of panes to display in this tab
  /// Each pane shows one TextLayer (edition + language + script combination)
  /// Empty list means using legacy dual-pane mode (Pali + Sinhala)
  /// Nullable for backward compatibility
  @override
  @JsonKey()
  List<ReaderPane> get panes {
    if (_panes is EqualUnmodifiableListView) return _panes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_panes);
  }

  @override
  String toString() {
    return 'ReaderTab(label: $label, fullName: $fullName, contentFileId: $contentFileId, pageIndex: $pageIndex, pageStart: $pageStart, pageEnd: $pageEnd, entryStart: $entryStart, nodeKey: $nodeKey, paliName: $paliName, sinhalaName: $sinhalaName, textId: $textId, panes: $panes)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReaderTabImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.contentFileId, contentFileId) ||
                other.contentFileId == contentFileId) &&
            (identical(other.pageIndex, pageIndex) ||
                other.pageIndex == pageIndex) &&
            (identical(other.pageStart, pageStart) ||
                other.pageStart == pageStart) &&
            (identical(other.pageEnd, pageEnd) || other.pageEnd == pageEnd) &&
            (identical(other.entryStart, entryStart) ||
                other.entryStart == entryStart) &&
            (identical(other.nodeKey, nodeKey) || other.nodeKey == nodeKey) &&
            (identical(other.paliName, paliName) ||
                other.paliName == paliName) &&
            (identical(other.sinhalaName, sinhalaName) ||
                other.sinhalaName == sinhalaName) &&
            (identical(other.textId, textId) || other.textId == textId) &&
            const DeepCollectionEquality().equals(other._panes, _panes));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      label,
      fullName,
      contentFileId,
      pageIndex,
      pageStart,
      pageEnd,
      entryStart,
      nodeKey,
      paliName,
      sinhalaName,
      textId,
      const DeepCollectionEquality().hash(_panes));

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReaderTabImplCopyWith<_$ReaderTabImpl> get copyWith =>
      __$$ReaderTabImplCopyWithImpl<_$ReaderTabImpl>(this, _$identity);
}

abstract class _ReaderTab extends ReaderTab {
  const factory _ReaderTab(
      {required final String label,
      required final String fullName,
      final String? contentFileId,
      final int pageIndex,
      final int pageStart,
      final int pageEnd,
      final int entryStart,
      final String? nodeKey,
      final String? paliName,
      final String? sinhalaName,
      final String? textId,
      final List<ReaderPane> panes}) = _$ReaderTabImpl;
  const _ReaderTab._() : super._();

  /// Short label for tab display (truncated if needed)
  @override
  String get label;

  /// Full name for tooltip or expanded view
  @override
  String get fullName;

  /// ID of the content file currently loaded in this tab
  @override
  String? get contentFileId;

  /// Current page index within the content file
  @override
  int get pageIndex;

  /// Start of loaded page range (for pagination)
  @override
  int get pageStart;

  /// End of loaded page range (for pagination, exclusive)
  @override
  int get pageEnd;

  /// Entry index to start from on the first visible page
  /// This allows opening a sutta mid-page without showing earlier entries
  @override
  int get entryStart;

  /// Reference to the tree node key for navigation sync
  @override
  String? get nodeKey;

  /// Pali name of the node for reference
  @override
  String? get paliName;

  /// Sinhala name of the node for reference
  @override
  String? get sinhalaName;

  /// Universal text identifier (e.g., 'dn1', 'mn100', 'sn1-1')
  /// This is edition-agnostic and used for cross-edition alignment
  /// Nullable for backward compatibility - derived from contentFileId if needed
  @override
  String? get textId;

  /// List of panes to display in this tab
  /// Each pane shows one TextLayer (edition + language + script combination)
  /// Empty list means using legacy dual-pane mode (Pali + Sinhala)
  /// Nullable for backward compatibility
  @override
  List<ReaderPane> get panes;

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReaderTabImplCopyWith<_$ReaderTabImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
