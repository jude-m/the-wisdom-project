import '../reader/reader_unit.dart';
import 'search_result.dart';
import 'search_result_type.dart';

/// Which node a [SearchResult] actually names.
extension SearchResultUnitKey on SearchResult {
  /// The node whose text the result sits on, derived from its row.
  ///
  /// Only a full-text hit is addressed by its row: the search database
  /// implements the slicing rule against the *raw* tree, so wherever a
  /// coordinate was corrected its stored `nodeKey` names an adjacent sibling.
  /// Every other kind of result was built *from* a node and carries that node's
  /// own coordinates, so asking the row again is a round trip — identity except
  /// where two nodes share a coordinate and [ReaderUnitResolver.keyAt] answers
  /// with the deeper one, which would rename සුත්තන්තපිටක to දීඝනිකායො.
  ///
  /// A null [resolver] is a tree that has not loaded; the stored key stands in.
  String unitKey(ReaderUnitResolver? resolver) =>
      resultType == SearchResultType.fullText
          ? resolver?.keyAt(contentFileId, pageIndex, entryIndex) ?? nodeKey
          : nodeKey;
}
