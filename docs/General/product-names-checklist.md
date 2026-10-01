# Product names: where they live

**The rule.** The static site is the Buddha Jayanti flagship and has its own
name. The app (mobile, desktop and Flutter web) is **Sammaditthi**, a name that
does not change if more editions (e.g. SuttaCentral) are added. "Buddha
Jayanti" goes in descriptions only, and only for the Tipitaka: the commentaries
are not Buddha Jayanti.

## App name

There is no single source: each platform reads its own file. Change them all
together.

| Shows up in | File | Change |
|---|---|---|
| App title, Android recents, web tab once loaded | `lib/core/localization/l10n/app_en.arb`, `app_si.arb` | `appTitle`, then `flutter gen-l10n` |
| Android launcher | `android/app/src/main/AndroidManifest.xml` | `android:label` |
| iOS home screen | `ios/Runner/Info.plist` | `CFBundleDisplayName` |
| macOS `.app` name, menu bar, window | `macos/Runner/Configs/AppInfo.xcconfig` | `PRODUCT_NAME` |
| References to that `.app` | `macos/Runner.xcodeproj/project.pbxproj` (`TEST_HOST`, product reference), `macos/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` (`BuildableName`) | `<name>.app` |
| Linux title bar | `linux/my_application.cc` | both `set_title` calls |
| Windows title bar | `windows/runner/main.cpp` | `window.Create(L"…")` |
| Windows Task Manager | `windows/runner/Runner.rc` | `FileDescription` only (not `ProductName`, see below) |
| Web tab before load, iOS bookmark | `web/index.html` | `<title>`, `apple-mobile-web-app-title` |
| Installed web app | `web/manifest.json` | `name`, `short_name` |

Renaming the macOS `.app` keeps the user's data: the sandbox container is keyed
by the bundle id, not the name.

## App description

The same sentence in `web/index.html` (`<meta name="description">`) and
`web/manifest.json` (`description`); store listings will join them. When an
edition is added, this changes, not the name.

## Static site

| What | Where |
|---|---|
| Site name (`og:site_name`, `/` title and heading) | `siteName` in `static_site_generator/lib/render/document_shell.dart` |
| `/` description | `_description` in `static_site_generator/lib/render/landing_page.dart` |
| UI labels shared with the app (search, layouts, home…) | `lib/core/localization/l10n/app_si.arb`, read at build time; the keys are `appStringKeys` in `static_site_generator/lib/domain/app_strings.dart` |

`siteName` is deliberately not the app's `appTitle`. To give the site its own
wording for one shared label, move that key into a site constant like
`siteName`.

## Do not rename

The technical name stays `the_wisdom_project` / `theWisdomProject`: Dart
package, bundle and application ids, Android namespace, `BINARY_NAME` (Linux,
Windows), `InternalName` and `OriginalFilename` in `Runner.rc`, iOS
`CFBundleName`. A new bundle or application id is a different app to the OS,
and the old one's data and settings stay behind.

`CompanyName` and `ProductName` in `Runner.rc` look like labels but are not:
`path_provider` names the Windows data folder after them
(`%APPDATA%\<CompanyName>\<ProductName>`), where `bjt.db` and the settings
live. Changing either moves that folder and leaves the user's data behind.

## After a rename

```sh
git grep -n "<old name>" -- lib web android ios macos linux windows static_site_generator/lib
```

Then run the app once on macOS (`flutter run -d macos`) to confirm the bundle
still builds and launches.
