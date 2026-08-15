import 'dart:convert';

/// FNV-1a, 64-bit, as a 16-character lowercase hex string.
///
/// **Change detection, not cryptography.** The only question asked of it is
/// "did these bytes change since the last build?" — by `.manifest.json` of the
/// 285 corpus files, and by `SiteAssets` of everything the pages link — where
/// an accidental collision is somewhere around 1 in 10^15. Rolling it by
/// hand keeps the generator's dependency list empty, which is worth more here
/// than a stronger digest: PREREQ-3's proof is that this package builds under a
/// bare `dart` SDK.
///
/// Lives in `domain/` rather than beside its consumer in `manifest/` because
/// `data/` needs it too, and `data/ -> manifest/` would have the layers
/// pointing the wrong way. It is a pure string transform with no I/O, so
/// `domain/` costs it nothing.
///
/// The result is formatted in two 32-bit halves because Dart ints are *signed*:
/// no Dart int can hold the unsigned 64-bit result, so `toRadixString(16)` on
/// the whole word prints a minus sign for the ~51% of inputs whose top bit is
/// set — and `padLeft` then buries that sign mid-string (`00000000-75bcd15`).
/// Halving the word sidesteps the sign, and makes the output match the
/// published FNV-1a-64 vectors: `''` hashes to the offset basis
/// `cbf29ce484222325`, and `'a'` to `af63dc4c8601ec8c`.
String contentHash(String content) => contentHashOfBytes(utf8.encode(content));

/// The same digest over bytes that are not text.
///
/// The emblem and the WOFF2 subsets are versioned by content like everything
/// else the site links (`SiteAssets`), and decoding a PNG as UTF-8 to reach
/// [contentHash] would throw on the first invalid sequence.
String contentHashOfBytes(List<int> bytes) {
  const offsetBasis = 0xcbf29ce484222325;
  const prime = 0x100000001b3;
  var hash = offsetBasis;
  for (final byte in bytes) {
    hash ^= byte;
    // Dart ints are 64-bit two's complement and wrap on overflow, which is
    // exactly the arithmetic FNV specifies.
    hash *= prime;
  }
  // `>>>` is the unsigned shift, so the high half arrives already masked; only
  // the low half needs one. (A `& 0xFFFFFFFFFFFFFFFF` here would be `& -1` —
  // a no-op that merely looks like it is handling the sign.)
  final high = hash >>> 32;
  final low = hash & 0xFFFFFFFF;
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}
