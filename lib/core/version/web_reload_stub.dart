/// Native / non-web stub. There's no browser window to reload, so this
/// is intentionally a no-op — keeps the banner UI buildable across all
/// platforms without ifdef'ing every call site.
void reloadPage() {
  // No-op outside the browser.
}
