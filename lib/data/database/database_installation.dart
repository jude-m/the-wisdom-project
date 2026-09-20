// Conditional export, the same split as `local_database_executor.dart`: only
// the web file can reach OPFS, and only a web build can import what it needs
// to. `dart.library.js_interop` is the web compile target.
export 'database_install_status.dart';
export 'database_installation_native.dart'
    if (dart.library.js_interop) 'database_installation_web.dart';
