// Conditional export: uses dart:io version on native, web stub on web.
// This avoids importing dart:io on web (which would fail).
export 'platform_utils_io.dart' if (dart.library.html) 'platform_utils_web.dart';
