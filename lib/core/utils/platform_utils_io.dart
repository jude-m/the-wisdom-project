import 'dart:io' show Platform;

/// Returns true if running on Windows or Linux (needs FFI SQLite init).
bool isDesktopPlatform() {
  return Platform.isWindows || Platform.isLinux;
}
