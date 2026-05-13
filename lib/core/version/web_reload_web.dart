import 'dart:js_interop';

/// Direct binding to `window.location.reload()` via the modern
/// `dart:js_interop` API. We avoid the legacy `dart:html` package
/// (deprecated by the Dart team) and we don't pull in `package:web`
/// just for this one call — the SDK's interop is enough.
@JS('window.location.reload')
external void _windowLocationReload();

/// Performs a full browser reload, fetching the latest static assets
/// from the server. Equivalent to the user pressing the reload button.
void reloadPage() => _windowLocationReload();
