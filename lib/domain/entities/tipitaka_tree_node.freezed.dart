// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tipitaka_tree_node.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$TipitakaTreeNode {
  /// Unique key identifying this node in the tree structure
  String get nodeKey => throw _privateConstructorUsedError;

  /// Display name in Pali language
  String get paliName => throw _privateConstructorUsedError;

  /// Display name in Sinhala language
  String get sinhalaName => throw _privateConstructorUsedError;

  /// The hierarchical level/depth of this node in the tree (0 = root)
  int get hierarchyLevel => throw _privateConstructorUsedError;

  /// Index of the entry's page in the content file
  int get entryPageIndex => throw _privateConstructorUsedError;

  /// Index of the entry within the page
  int get entryIndexInPage => throw _privateConstructorUsedError;

  /// Key of the parent node (null for root nodes)
  String? get parentNodeKey => throw _privateConstructorUsedError;

  /// ID of the content file associated with this node (null for container nodes)
  String? get contentFileId => throw _privateConstructorUsedError;

  /// List of child nodes (empty for leaf nodes)
  List<TipitakaTreeNode> get childNodes => throw _privateConstructorUsedError;

  /// Indicates whether audio is available for this content
  bool get hasAudioAvailable => throw _privateConstructorUsedError;

  /// Create a copy of TipitakaTreeNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $TipitakaTreeNodeCopyWith<TipitakaTreeNode> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $TipitakaTreeNodeCopyWith<$Res> {
  factory $TipitakaTreeNodeCopyWith(
          TipitakaTreeNode value, $Res Function(TipitakaTreeNode) then) =
      _$TipitakaTreeNodeCopyWithImpl<$Res, TipitakaTreeNode>;
  @useResult
  $Res call(
      {String nodeKey,
      String paliName,
      String sinhalaName,
      int hierarchyLevel,
      int entryPageIndex,
      int entryIndexInPage,
      String? parentNodeKey,
      String? contentFileId,
      List<TipitakaTreeNode> childNodes,
      bool hasAudioAvailable});
}

/// @nodoc
class _$TipitakaTreeNodeCopyWithImpl<$Res, $Val extends TipitakaTreeNode>
    implements $TipitakaTreeNodeCopyWith<$Res> {
  _$TipitakaTreeNodeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of TipitakaTreeNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeKey = null,
    Object? paliName = null,
    Object? sinhalaName = null,
    Object? hierarchyLevel = null,
    Object? entryPageIndex = null,
    Object? entryIndexInPage = null,
    Object? parentNodeKey = freezed,
    Object? contentFileId = freezed,
    Object? childNodes = null,
    Object? hasAudioAvailable = null,
  }) {
    return _then(_value.copyWith(
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      paliName: null == paliName
          ? _value.paliName
          : paliName // ignore: cast_nullable_to_non_nullable
              as String,
      sinhalaName: null == sinhalaName
          ? _value.sinhalaName
          : sinhalaName // ignore: cast_nullable_to_non_nullable
              as String,
      hierarchyLevel: null == hierarchyLevel
          ? _value.hierarchyLevel
          : hierarchyLevel // ignore: cast_nullable_to_non_nullable
              as int,
      entryPageIndex: null == entryPageIndex
          ? _value.entryPageIndex
          : entryPageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      entryIndexInPage: null == entryIndexInPage
          ? _value.entryIndexInPage
          : entryIndexInPage // ignore: cast_nullable_to_non_nullable
              as int,
      parentNodeKey: freezed == parentNodeKey
          ? _value.parentNodeKey
          : parentNodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      contentFileId: freezed == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String?,
      childNodes: null == childNodes
          ? _value.childNodes
          : childNodes // ignore: cast_nullable_to_non_nullable
              as List<TipitakaTreeNode>,
      hasAudioAvailable: null == hasAudioAvailable
          ? _value.hasAudioAvailable
          : hasAudioAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$TipitakaTreeNodeImplCopyWith<$Res>
    implements $TipitakaTreeNodeCopyWith<$Res> {
  factory _$$TipitakaTreeNodeImplCopyWith(_$TipitakaTreeNodeImpl value,
          $Res Function(_$TipitakaTreeNodeImpl) then) =
      __$$TipitakaTreeNodeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String nodeKey,
      String paliName,
      String sinhalaName,
      int hierarchyLevel,
      int entryPageIndex,
      int entryIndexInPage,
      String? parentNodeKey,
      String? contentFileId,
      List<TipitakaTreeNode> childNodes,
      bool hasAudioAvailable});
}

/// @nodoc
class __$$TipitakaTreeNodeImplCopyWithImpl<$Res>
    extends _$TipitakaTreeNodeCopyWithImpl<$Res, _$TipitakaTreeNodeImpl>
    implements _$$TipitakaTreeNodeImplCopyWith<$Res> {
  __$$TipitakaTreeNodeImplCopyWithImpl(_$TipitakaTreeNodeImpl _value,
      $Res Function(_$TipitakaTreeNodeImpl) _then)
      : super(_value, _then);

  /// Create a copy of TipitakaTreeNode
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? nodeKey = null,
    Object? paliName = null,
    Object? sinhalaName = null,
    Object? hierarchyLevel = null,
    Object? entryPageIndex = null,
    Object? entryIndexInPage = null,
    Object? parentNodeKey = freezed,
    Object? contentFileId = freezed,
    Object? childNodes = null,
    Object? hasAudioAvailable = null,
  }) {
    return _then(_$TipitakaTreeNodeImpl(
      nodeKey: null == nodeKey
          ? _value.nodeKey
          : nodeKey // ignore: cast_nullable_to_non_nullable
              as String,
      paliName: null == paliName
          ? _value.paliName
          : paliName // ignore: cast_nullable_to_non_nullable
              as String,
      sinhalaName: null == sinhalaName
          ? _value.sinhalaName
          : sinhalaName // ignore: cast_nullable_to_non_nullable
              as String,
      hierarchyLevel: null == hierarchyLevel
          ? _value.hierarchyLevel
          : hierarchyLevel // ignore: cast_nullable_to_non_nullable
              as int,
      entryPageIndex: null == entryPageIndex
          ? _value.entryPageIndex
          : entryPageIndex // ignore: cast_nullable_to_non_nullable
              as int,
      entryIndexInPage: null == entryIndexInPage
          ? _value.entryIndexInPage
          : entryIndexInPage // ignore: cast_nullable_to_non_nullable
              as int,
      parentNodeKey: freezed == parentNodeKey
          ? _value.parentNodeKey
          : parentNodeKey // ignore: cast_nullable_to_non_nullable
              as String?,
      contentFileId: freezed == contentFileId
          ? _value.contentFileId
          : contentFileId // ignore: cast_nullable_to_non_nullable
              as String?,
      childNodes: null == childNodes
          ? _value._childNodes
          : childNodes // ignore: cast_nullable_to_non_nullable
              as List<TipitakaTreeNode>,
      hasAudioAvailable: null == hasAudioAvailable
          ? _value.hasAudioAvailable
          : hasAudioAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$TipitakaTreeNodeImpl extends _TipitakaTreeNode {
  const _$TipitakaTreeNodeImpl(
      {required this.nodeKey,
      required this.paliName,
      required this.sinhalaName,
      required this.hierarchyLevel,
      required this.entryPageIndex,
      required this.entryIndexInPage,
      this.parentNodeKey,
      this.contentFileId,
      final List<TipitakaTreeNode> childNodes = const [],
      this.hasAudioAvailable = false})
      : _childNodes = childNodes,
        super._();

  /// Unique key identifying this node in the tree structure
  @override
  final String nodeKey;

  /// Display name in Pali language
  @override
  final String paliName;

  /// Display name in Sinhala language
  @override
  final String sinhalaName;

  /// The hierarchical level/depth of this node in the tree (0 = root)
  @override
  final int hierarchyLevel;

  /// Index of the entry's page in the content file
  @override
  final int entryPageIndex;

  /// Index of the entry within the page
  @override
  final int entryIndexInPage;

  /// Key of the parent node (null for root nodes)
  @override
  final String? parentNodeKey;

  /// ID of the content file associated with this node (null for container nodes)
  @override
  final String? contentFileId;

  /// List of child nodes (empty for leaf nodes)
  final List<TipitakaTreeNode> _childNodes;

  /// List of child nodes (empty for leaf nodes)
  @override
  @JsonKey()
  List<TipitakaTreeNode> get childNodes {
    if (_childNodes is EqualUnmodifiableListView) return _childNodes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_childNodes);
  }

  /// Indicates whether audio is available for this content
  @override
  @JsonKey()
  final bool hasAudioAvailable;

  @override
  String toString() {
    return 'TipitakaTreeNode(nodeKey: $nodeKey, paliName: $paliName, sinhalaName: $sinhalaName, hierarchyLevel: $hierarchyLevel, entryPageIndex: $entryPageIndex, entryIndexInPage: $entryIndexInPage, parentNodeKey: $parentNodeKey, contentFileId: $contentFileId, childNodes: $childNodes, hasAudioAvailable: $hasAudioAvailable)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$TipitakaTreeNodeImpl &&
            (identical(other.nodeKey, nodeKey) || other.nodeKey == nodeKey) &&
            (identical(other.paliName, paliName) ||
                other.paliName == paliName) &&
            (identical(other.sinhalaName, sinhalaName) ||
                other.sinhalaName == sinhalaName) &&
            (identical(other.hierarchyLevel, hierarchyLevel) ||
                other.hierarchyLevel == hierarchyLevel) &&
            (identical(other.entryPageIndex, entryPageIndex) ||
                other.entryPageIndex == entryPageIndex) &&
            (identical(other.entryIndexInPage, entryIndexInPage) ||
                other.entryIndexInPage == entryIndexInPage) &&
            (identical(other.parentNodeKey, parentNodeKey) ||
                other.parentNodeKey == parentNodeKey) &&
            (identical(other.contentFileId, contentFileId) ||
                other.contentFileId == contentFileId) &&
            const DeepCollectionEquality()
                .equals(other._childNodes, _childNodes) &&
            (identical(other.hasAudioAvailable, hasAudioAvailable) ||
                other.hasAudioAvailable == hasAudioAvailable));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      nodeKey,
      paliName,
      sinhalaName,
      hierarchyLevel,
      entryPageIndex,
      entryIndexInPage,
      parentNodeKey,
      contentFileId,
      const DeepCollectionEquality().hash(_childNodes),
      hasAudioAvailable);

  /// Create a copy of TipitakaTreeNode
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$TipitakaTreeNodeImplCopyWith<_$TipitakaTreeNodeImpl> get copyWith =>
      __$$TipitakaTreeNodeImplCopyWithImpl<_$TipitakaTreeNodeImpl>(
          this, _$identity);
}

abstract class _TipitakaTreeNode extends TipitakaTreeNode {
  const factory _TipitakaTreeNode(
      {required final String nodeKey,
      required final String paliName,
      required final String sinhalaName,
      required final int hierarchyLevel,
      required final int entryPageIndex,
      required final int entryIndexInPage,
      final String? parentNodeKey,
      final String? contentFileId,
      final List<TipitakaTreeNode> childNodes,
      final bool hasAudioAvailable}) = _$TipitakaTreeNodeImpl;
  const _TipitakaTreeNode._() : super._();

  /// Unique key identifying this node in the tree structure
  @override
  String get nodeKey;

  /// Display name in Pali language
  @override
  String get paliName;

  /// Display name in Sinhala language
  @override
  String get sinhalaName;

  /// The hierarchical level/depth of this node in the tree (0 = root)
  @override
  int get hierarchyLevel;

  /// Index of the entry's page in the content file
  @override
  int get entryPageIndex;

  /// Index of the entry within the page
  @override
  int get entryIndexInPage;

  /// Key of the parent node (null for root nodes)
  @override
  String? get parentNodeKey;

  /// ID of the content file associated with this node (null for container nodes)
  @override
  String? get contentFileId;

  /// List of child nodes (empty for leaf nodes)
  @override
  List<TipitakaTreeNode> get childNodes;

  /// Indicates whether audio is available for this content
  @override
  bool get hasAudioAvailable;

  /// Create a copy of TipitakaTreeNode
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$TipitakaTreeNodeImplCopyWith<_$TipitakaTreeNodeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
