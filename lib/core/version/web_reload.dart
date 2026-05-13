// Conditional export: on web, hits window.location.reload() via
// dart:js_interop; on every other platform, a no-op so the call site
// can stay platform-agnostic.
//
// The `dart.library.js_interop` flag is the canonical way to detect
// the web compile target — same pattern used by `platform_utils.dart`.
export 'web_reload_stub.dart'
    if (dart.library.js_interop) 'web_reload_web.dart';
