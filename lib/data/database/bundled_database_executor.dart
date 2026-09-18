// Conditional export: the native executor needs dart:ffi, which a web build
// cannot import. `dart.library.js_interop` is the web compile target.
export 'bundled_database_executor_native.dart'
    if (dart.library.js_interop) 'bundled_database_executor_web.dart';
