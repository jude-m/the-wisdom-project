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

ReaderTab _$ReaderTabFromJson(Map<String, dynamic> json) {
  return _ReaderTab.fromJson(json);
}

/// @nodoc
mixin _$ReaderTab {
  /// Short label for tab display (truncated if needed)
  String get label => throw _privateConstructorUsedError;

  /// Full name for tooltip or expanded view
  String get fullName => throw _privateConstructorUsedError;

  /// The node this tab reads. Its subtree is the unit. Null only for a tab
  /// with no content.
  String? get nodeKey => throw _privateConstructorUsedError;

  /// A landing position inside the unit — the row an FTS hit or a
  /// `?e=<page>.<entry>` link named, as a document coordinate.
  ///
  /// **Scroll position only.** The unit always comes from [nodeKey]; this
  /// says where inside it to stop, and the reader clears it the moment it
  /// lands. Null for every other way a tab opens.
  int? get landingPageIndex => throw _privateConstructorUsedError;
  int? get landingEntryIndex => throw _privateConstructorUsedError;

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

  /// Reader layout mode for this tab (per-tab setting)
  /// Defaults to paliOnly for portrait mode, can be changed by user
  ReaderLayout get layout => throw _privateConstructorUsedError;

  /// Split ratio for side-by-side layout (0.0 to 1.0)
  /// Represents the proportion of width for the left (Pali) pane
  double get splitRatio => throw _privateConstructorUsedError;

  /// Last known scroll offset (in pixels) for this tab.
  /// Persisted to disk so a reload resumes at the same reading position.
  double get scrollOffset => throw _privateConstructorUsedError;

  /// Serializes this ReaderTab to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

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
      String? nodeKey,
      int? landingPageIndex,
      int? landingEntryIndex,
      String? paliName,
      String? sinhalaName,
      String? textId,
      List<ReaderPane> panes,
      ReaderLayout layout,
      double splitRatio,
      double scrollOffset});
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
    Object? nodeKey = freezed,
    Object? landingPageIndex = freezed,
    Object? landingEntryIndex = freezed,
    Object? paliName = freezed,
    Object? sinhalaName = freezed,
    Object? textId = freezed,
    Object? panes = null,
    Object? layout = null,
    Object? splitRatio = null,
    Object? scrollOffset = null,
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
      nodeKey: freezed == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      landingPageIndex: freezed == landingPageIndex
          ? _value.landingPageIndex
          : landingPageIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      landingEntryIndex: freezed == landingEntryIndex
          ? _value.landingEntryIndex
          : landingEntryIndex // ignore: cast_nullable_to_non_nullable
              as int?,
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
      layout: null == layout
          ? _value.layout
          : layout // ignore: cast_nullable_to_non_nullable
              as ReaderLayout,
      splitRatio: null == splitRatio
          ? _value.splitRatio
          : splitRatio // ignore: cast_nullable_to_non_nullable
              as double,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
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
      String? nodeKey,
      int? landingPageIndex,
      int? landingEntryIndex,
      String? paliName,
      String? sinhalaName,
      String? textId,
      List<ReaderPane> panes,
      ReaderLayout layout,
      double splitRatio,
      double scrollOffset});
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
    Object? nodeKey = freezed,
    Object? landingPageIndex = freezed,
    Object? landingEntryIndex = freezed,
    Object? paliName = freezed,
    Object? sinhalaName = freezed,
    Object? textId = freezed,
    Object? panes = null,
    Object? layout = null,
    Object? splitRatio = null,
    Object? scrollOffset = null,
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
      nodeKey: freezed == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      landingPageIndex: freezed == landingPageIndex
          ? _value.landingPageIndex
          : landingPageIndex // ignore: cast_nullable_to_non_nullable
              as int?,
      landingEntryIndex: freezed == landingEntryIndex
          ? _value.landingEntryIndex
          : landingEntryIndex // ignore: cast_nullable_to_non_nullable
              as int?,
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
      layout: null == layout
          ? _value.layout
          : layout // ignore: cast_nullable_to_non_nullable
              as ReaderLayout,
      splitRatio: null == splitRatio
          ? _value.splitRatio
          : splitRatio // ignore: cast_nullable_to_non_nullable
              as double,
      scrollOffset: null == scrollOffset
          ? _value.scrollOffset
          : scrollOffset // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$ReaderTabImpl extends _ReaderTab {
  const _$ReaderTabImpl(
      {required this.label,
      required this.fullName,
      this.nodeKey,
      this.landingPageIndex,
      this.landingEntryIndex,
      this.paliName,
      this.sinhalaName,
      this.textId,
      final List<ReaderPane> panes = const [],
      this.layout = ReaderLayout.paliOnly,
      this.splitRatio = 0.5,
      this.scrollOffset = 0.0})
      : assert(splitRatio >= 0.0 && splitRatio <= 1.0,
            'splitRatio must be between 0.0 and 1.0'),
        _panes = panes,
        super._();

  factory _$ReaderTabImpl.fromJson(Map<String, dynamic> json) =>
      _$$ReaderTabImplFromJson(json);

  /// Short label for tab display (truncated if needed)
  @override
  final String label;

  /// Full name for tooltip or expanded view
  @override
  final String fullName;

  /// The node this tab reads. Its subtree is the unit. Null only for a tab
  /// with no content.
  @override
  final String? nodeKey;

  /// A landing position inside the unit — the row an FTS hit or a
  /// `?e=<page>.<entry>` link named, as a document coordinate.
  ///
  /// **Scroll position only.** The unit always comes from [nodeKey]; this
  /// says where inside it to stop, and the reader clears it the moment it
  /// lands. Null for every other way a tab opens.
  @override
  final int? landingPageIndex;
  @override
  final int? landingEntryIndex;

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

  /// Reader layout mode for this tab (per-tab setting)
  /// Defaults to paliOnly for portrait mode, can be changed by user
  @override
  @JsonKey()
  final ReaderLayout layout;

  /// Split ratio for side-by-side layout (0.0 to 1.0)
  /// Represents the proportion of width for the left (Pali) pane
  @override
  @JsonKey()
  final double splitRatio;

  /// Last known scroll offset (in pixels) for this tab.
  /// Persisted to disk so a reload resumes at the same reading position.
  @override
  @JsonKey()
  final double scrollOffset;

  @override
  String toString() {
    return 'ReaderTab(label: $label, fullName: $fullName, nodeKey: $nodeKey, landingPageIndex: $landingPageIndex, landingEntryIndex: $landingEntryIndex, paliName: $paliName, sinhalaName: $sinhalaName, textId: $textId, panes: $panes, layout: $layout, splitRatio: $splitRatio, scrollOffset: $scrollOffset)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ReaderTabImpl &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.fullName, fullName) ||
                other.fullName == fullName) &&
            (identical(other.nodeKey, nodeKey) || other.nodeKey == nodeKey) &&
            (identical(other.landingPageIndex, landingPageIndex) ||
                other.landingPageIndex == landingPageIndex) &&
            (identical(other.landingEntryIndex, landingEntryIndex) ||
                other.landingEntryIndex == landingEntryIndex) &&
            (identical(other.paliName, paliName) ||
                other.paliName == paliName) &&
            (identical(other.sinhalaName, sinhalaName) ||
                other.sinhalaName == sinhalaName) &&
            (identical(other.textId, textId) || other.textId == textId) &&
            const DeepCollectionEquality().equals(other._panes, _panes) &&
            (identical(other.layout, layout) || other.layout == layout) &&
            (identical(other.splitRatio, splitRatio) ||
                other.splitRatio == splitRatio) &&
            (identical(other.scrollOffset, scrollOffset) ||
                other.scrollOffset == scrollOffset));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      label,
      fullName,
      nodeKey,
      landingPageIndex,
      landingEntryIndex,
      paliName,
      sinhalaName,
      textId,
      const DeepCollectionEquality().hash(_panes),
      layout,
      splitRatio,
      scrollOffset);

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ReaderTabImplCopyWith<_$ReaderTabImpl> get copyWith =>
      __$$ReaderTabImplCopyWithImpl<_$ReaderTabImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ReaderTabImplToJson(
      this,
    );
  }
}

abstract class _ReaderTab extends ReaderTab {
  const factory _ReaderTab(
      {required final String label,
      required final String fullName,
      final String? nodeKey,
      final int? landingPageIndex,
      final int? landingEntryIndex,
      final String? paliName,
      final String? sinhalaName,
      final String? textId,
      final List<ReaderPane> panes,
      final ReaderLayout layout,
      final double splitRatio,
      final double scrollOffset}) = _$ReaderTabImpl;
  const _ReaderTab._() : super._();

  factory _ReaderTab.fromJson(Map<String, dynamic> json) =
      _$ReaderTabImpl.fromJson;

  /// Short label for tab display (truncated if needed)
  @override
  String get label;

  /// Full name for tooltip or expanded view
  @override
  String get fullName;

  /// The node this tab reads. Its subtree is the unit. Null only for a tab
  /// with no content.
  @override
  String? get nodeKey;

  /// A landing position inside the unit — the row an FTS hit or a
  /// `?e=<page>.<entry>` link named, as a document coordinate.
  ///
  /// **Scroll position only.** The unit always comes from [nodeKey]; this
  /// says where inside it to stop, and the reader clears it the moment it
  /// lands. Null for every other way a tab opens.
  @override
  int? get landingPageIndex;
  @override
  int? get landingEntryIndex;

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

  /// Reader layout mode for this tab (per-tab setting)
  /// Defaults to paliOnly for portrait mode, can be changed by user
  @override
  ReaderLayout get layout;

  /// Split ratio for side-by-side layout (0.0 to 1.0)
  /// Represents the proportion of width for the left (Pali) pane
  @override
  double get splitRatio;

  /// Last known scroll offset (in pixels) for this tab.
  /// Persisted to disk so a reload resumes at the same reading position.
  @override
  double get scrollOffset;

  /// Create a copy of ReaderTab
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ReaderTabImplCopyWith<_$ReaderTabImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
