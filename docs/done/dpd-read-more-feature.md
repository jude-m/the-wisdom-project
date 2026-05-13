# DPD Dictionary "Read More" Feature

## Context

The `dict.db` database already embeds `<a href="https://www.dpdict.net/?q=WORD">Read more</a>` HTML links in DPD dictionary entry meanings — inherited from the old tipitaka.lk app. However, the current HTML parser in `dictionary_bottom_sheet.dart` (line 569) strips `<a>` tags, so these links are invisible. This feature makes them tappable, opening the DPD website in an in-app browser.

**User requirements:**
- Opens in-app browser (SFSafariViewController on iOS, Chrome Custom Tabs on Android, external browser fallback on desktop)
- DPD entries only
- Visible in both the dictionary bottom sheet and search result tiles

---

## Implementation Steps

### Step 1: Add `url_launcher` dependency

**File:** `pubspec.yaml` (line ~62)

Add `url_launcher: ^6.2.0` under dependencies.

Run `flutter pub get`.

### Step 2: Platform configuration

**Android** — `android/app/src/main/AndroidManifest.xml` (line 39-44)

Add a second `<intent>` inside the existing `<queries>` block for HTTPS URL verification (required on Android 11+):

```xml
<intent>
    <action android:name="android.intent.action.VIEW"/>
    <data android:scheme="https"/>
</intent>
```

**macOS** — `macos/Runner/DebugProfile.entitlements` (after line 10)

Add outgoing network entitlement (currently only has `network.server`):
```xml
<key>com.apple.security.network.client</key>
<true/>
```

**macOS** — `macos/Runner/Release.entitlements` (after line 5)

Add the same key (currently only has `app-sandbox`):
```xml
<key>com.apple.security.network.client</key>
<true/>
```

**iOS / Windows / Linux** — No changes needed.

### Step 3: Create URL launcher utility

**New file:** `lib/core/utils/url_launcher_utils.dart`

`abstract final class UrlLauncherUtils` with two static methods:

1. `launchInAppBrowser(BuildContext context, String urlString)` — Parses URI, calls `launchUrl` with `LaunchMode.inAppBrowserView`, shows SnackBar on failure.
2. `extractFirstHref(String html)` — Regex extracts first `href` from `<a>` tags. Returns `String?`. Used by the search tile to get the URL without full HTML parsing.

### Step 4: Modify bottom sheet HTML parser

**File:** `lib/presentation/widgets/dictionary/dictionary_bottom_sheet.dart`

**4a.** Add imports: `package:flutter/gestures.dart` and `url_launcher_utils.dart`.

**4b.** Convert `_DictionaryEntryTile` (line 454) from `StatelessWidget` to `StatefulWidget` — needed to properly dispose `TapGestureRecognizer` instances.

**4c.** Modify `_parseHtmlToTextSpans` (line 520):
- Track `currentHref` and `isLink` state when parsing `<a href="...">` and `</a>` tags
- Pass `BuildContext` as additional parameter
- When inside a DPD `<a>` tag, create `TextSpan` with:
  - `TapGestureRecognizer` that calls `UrlLauncherUtils.launchInAppBrowser`
  - Primary color + underline styling

**4d.** Replace `_createTextSpan` with `_createStyledSpan` that handles the link case:
- If `isLink && href != null && widget.entry.dictionaryId == 'DPD'`: tappable, styled span
- Otherwise: plain text span (existing behavior)

**4e.** Manage recognizer lifecycle:
- Store recognizers in a `List<TapGestureRecognizer>`
- Dispose all in `dispose()`
- Clear and re-dispose on each `build()` before parsing

### Step 5: Add "Read more" link to search result tile

**File:** `lib/presentation/widgets/search/dictionary_search_result_tile.dart`

**5a.** Import `url_launcher_utils.dart`.

**5b.** After the truncated meaning `Text` widget (line 66-71), conditionally add for DPD entries:
- Check `result.editionId == 'DPD'`
- Extract URL via `UrlLauncherUtils.extractFirstHref(result.matchedText)`
- If URL found, render a `GestureDetector` + `Text('Read more on DPD')` styled with primary color and underline
- `GestureDetector.onTap` calls `UrlLauncherUtils.launchInAppBrowser`

The `GestureDetector` on the link takes tap priority over the `ListTile.onTap`, so tapping "Read more" won't also trigger the bottom sheet.

---

## Files Summary

| File | Action |
|------|--------|
| `pubspec.yaml` | Modify — add `url_launcher` |
| `android/app/src/main/AndroidManifest.xml` | Modify — add HTTPS intent query |
| `macos/Runner/DebugProfile.entitlements` | Modify — add network.client |
| `macos/Runner/Release.entitlements` | Modify — add network.client |
| `lib/core/utils/url_launcher_utils.dart` | **Create** — URL launch + href extraction utility |
| `lib/presentation/widgets/dictionary/dictionary_bottom_sheet.dart` | Modify — make `<a>` tags tappable for DPD |
| `lib/presentation/widgets/search/dictionary_search_result_tile.dart` | Modify — add "Read more on DPD" link |

---

## Verification

1. **Bottom sheet**: Tap a Pali word to open dictionary bottom sheet → find a DPD entry → confirm "Read more" appears as a tappable blue underlined link → tap it → verify DPD website opens in in-app browser
2. **Search tile**: Search for a word → find a DPD result in dictionary tab → confirm "Read more on DPD" link appears below the truncated meaning → tap it → verify in-app browser opens
3. **Non-DPD entries**: Verify other dictionary entries (PTS, BUS, etc.) do NOT show a "Read more" link
4. **Desktop fallback**: On macOS, verify the link opens in the default browser
5. **No link in data**: Verify entries without `<a>` tags render normally with no errors
