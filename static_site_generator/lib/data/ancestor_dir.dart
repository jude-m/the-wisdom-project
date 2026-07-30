import 'dart:io';

/// Walks up from [start] and returns the first directory [isMatch] accepts, or
/// null if none is found within [maxDepth] levels.
///
/// The generator has to resolve two things by searching upwards — the app's
/// `assets/` and its own package root — because it is run both from the repo
/// root and from inside `static_site_generator/`. Those two searches differ
/// only in the landmark they look for, so the walk itself lives here once.
///
/// [maxDepth] is a guard, not a tuning knob: it stops a misconfigured run from
/// climbing out of the checkout and matching something unrelated on the way to
/// `/`.
Directory? findAncestorDir(
  bool Function(Directory directory) isMatch, {
  Directory? start,
  int maxDepth = 5,
}) {
  var directory = start ?? Directory.current;
  for (var depth = 0; depth < maxDepth; depth++) {
    if (isMatch(directory)) return directory;
    final parent = directory.parent;
    if (parent.path == directory.path) break; // hit the filesystem root
    directory = parent;
  }
  return null;
}
