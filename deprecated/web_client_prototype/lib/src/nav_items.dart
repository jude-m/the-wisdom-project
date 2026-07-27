/// Hardcoded navigator list for the prototype (~5 real content files).
/// The real build replaces this with the tree navigator fed by tree.json.
/// Names are the Pali names from assets/data/tree.json.
library;

typedef NavItem = ({String fileId, String name});

const List<NavItem> navSuttas = [
  (fileId: 'dn-1', name: 'සීලක්ඛන්ධවග්ගො'),
  (fileId: 'dn-2', name: 'මහාවග්ගො'),
  (fileId: 'mn-1', name: 'මූලපණ්ණාසකො'),
  (fileId: 'sn-1', name: 'සගාථවග්ගො'),
  (fileId: 'an-1', name: 'එකක නිපාතො'),
];

/// Display name for a content file, falling back to the raw fileId for
/// files not in the hardcoded list (e.g. opened from a search result).
String displayNameFor(String fileId) {
  for (final item in navSuttas) {
    if (item.fileId == fileId) return item.name;
  }
  return fileId;
}
