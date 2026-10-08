# Flutter 3.47 upgrade — findings and plan

> **Status 2026-10-08: not started.** Investigation only; nothing in the repo
> has changed yet. Recommendation: move from 3.44.1 to 3.47.6 now, in one
> branch, before the November stable release.

## Why upgrade now

- 3.44 gets no more fixes. Flutter only patches the newest stable, and 3.44.9
  (2026-08-06) was the last 3.44 release.
- 3.47.x fixes Xcode 27 and iOS 27 problems: a white screen and a hang when
  debugging with Xcode 27 (3.47.4), crashes while debugging on iOS 27 devices
  (3.47.5). The first mobile release needs these.
- The next stable (expected November) formally deprecates
  `package:flutter/material.dart`. Taking 3.47 on its own first keeps the two
  changes apart.

## Versions

| | Now | Target |
| --- | --- | --- |
| Flutter | 3.44.1 | 3.47.6 (2026-10-01) |
| Dart | 3.12.1 | 3.13.5 |
| `sdk:` in `pubspec.yaml` | `>=3.5.2 <4.0.0` | unchanged in step 1, `^3.13.0` in step 3 |

The real floor is already 3.44: `app_links` 7.2.0 needs Flutter 3.44 and
Dart 3.12.

## What was tested (2026-10-08)

The full macOS SDK zip is 2.3 GB, so the trial used the Dart 3.13.5 SDK and
the 3.47.6 framework source (with its `sky_engine`) on a copy of the repo,
with `FLUTTER_ROOT` pointing at that framework. The same steps on 3.44.1 were
the control.

| Check | Result on 3.47.6 |
| --- | --- |
| `pub get` | Resolves with no `pubspec.yaml` change. Only indirect packages move: intl 0.20.3, meta 1.19.0, vector_math 2.4.3, test_api 0.7.12, matcher 0.12.20. |
| `dart analyze` on `lib`, `test`, `integration_test`, `test_driver`, `tools` | No issues, as on 3.44.1. |
| The `dart format` check in `scripts/app/test.sh` | No file changes while `sdk:` stays at 3.5. |
| `build_runner` | Crashes. Works after step 1's version bumps. |
| `wisdom_shared`, `static_site_generator` | Analyze clean. |
| Static site build | Every output file byte-identical to the Dart 3.12.1 build. Same build time, about 24 s. |

Not tested: `flutter test`, the integration tests, macOS rendering and the web
build. They need the full SDK; step 2 covers them.

## What breaks

### Code generation

3.47's own code uses Dart's dot shorthand. From
`packages/flutter/lib/src/services/platform_views.dart`:

```dart
UiKitViewGestureBlockingPolicy gestureBlockingPolicy = .fallbackToPluginDefault,
```

freezed 2.5.8 pins analyzer 7.7.1, which can't read that. `build_runner`
fails on the first file with `Exception: Missing implementation of
visitDotShorthandPropertyAccess`, then hangs. The same run on 3.44.1 passes,
and its output matches the committed generated files byte for byte.

Step 1 fixes it: newer generators, plus `abstract` or `sealed` on every
`@freezed` class. With those, every generated file builds in about 27 s and
`dart analyze` stays clean.

- The `.when(...)` calls in `lib/` are Riverpod's `AsyncValue.when`, not
  freezed's. freezed 4 still generates `when`/`map`, which
  `Failure.userMessage` uses.
- Riverpod 2.6.1 needs no change.
- json_serializable 6.14 prints a warning until `sdk:` is at least 3.8
  (step 3).
- build_runner 2.16 ignores `--delete-conflicting-outputs` and prints a
  warning. `scripts/app/test.sh:72`, `CLAUDE.md` and a few docs still pass it.
- Generated files grow by about a third. Release builds strip most of it.

### Edits Flutter makes by itself

- `flutter pub get` adds excludes for `build/` and the platform folders to
  `analysis_options.yaml`.
- The first macOS build raises the minimum macOS from 10.15 to 12 in
  `macos/Runner.xcodeproj/project.pbxproj`. The app stops running on
  macOS 10.15 and 11.
- The minimum iOS goes from 13 to 15. Check `ios/Runner.xcodeproj/project.pbxproj`
  after the first iOS build.
- The first iOS build moves the app to the UIScene lifecycle. This is
  automatic for a stock `AppDelegate` since 3.41, so it isn't new in 3.47.
  Xcode 27 requires it.

### Already broken: Android

The upgrade didn't cause this. Flutter 3.44.1 already refuses this setup:

| | Repo | 3.44.1 refuses below | 3.47.6 refuses below | 3.47 template |
| --- | --- | --- | --- | --- |
| Gradle (`android/gradle/wrapper/gradle-wrapper.properties:5`) | 8.3 | 8.7 | 8.14 | 9.3.1 |
| Android Gradle Plugin (`android/settings.gradle:21`) | 8.1.0 | 8.6 | 8.11.1 | 9.1.0 |
| Kotlin plugin (`android/settings.gradle:22`) | 1.8.22 | 2.0 | 2.2.20 | 2.4.0 |
| Java (`android/app/build.gradle:14`) | 1.8 | 17 | 17 | 17 |

Fix it with the first Android build
([first-mobile-release.md](mobile-release/first-mobile-release.md), section 1).
AGP 9 has Kotlin built in, so the `kotlin-android` plugin goes. Keep the
manifest's label and deep-link filters.

## Benefits

- Text-selection fixes in widgets the reader uses: a `SelectableRegion` crash,
  selecting backwards across widget spans, and highlight glitches on faded
  text.
- Screen readers now read nested `Text.rich` in layout order.
- Widget Previews are stable.
- Newer Dart syntax once `sdk:` is raised (step 4).
- Not fixed: the Windows Sinhala IME bug. Its fix (#189968) is only on Flutter
  master so far; see
  [windows-sinhala-ime-bug.md](../General/windows-sinhala-ime-bug.md) for when
  it reaches stable.

## Performance

- **macOS: Impeller replaces Skia as the renderer** (on Metal). Shaders are
  compiled at build time, so animations don't stutter the first time they run.
  Text uses SDF rendering, which Flutter says is sharper. Wide colour is on.
  - Text may look slightly different, so compare Sinhala and Pali in step 2.
  - Open bug: text smears while another app saturates the GPU and memory,
    e.g. a local AI model
    ([#193927](https://github.com/flutter/flutter/issues/193927), opened
    2026-10-06, not triaged).
  - Temporary opt-out, in `macos/Runner/Info.plist` (Flutter will remove it in
    a later release):

    ```xml
    <key>FLTEnableImpeller</key>
    <false/>
    ```

- **Web:** the default build (JS, CanvasKit) gets only small engine fixes, so
  no visible change is expected. A later option is `flutter build web --wasm`:
  the app is already cross-origin isolated (`web/_headers`) and uses
  `package:web`, not `dart:html`. Untested.
- **Dev:** code generation takes about the same time (22 s on 3.44.1, 27 s on
  3.47.6 including a one-time compile). The static site build time is
  unchanged.
- Flutter published no benchmark figures for 3.47.

## How to use this plan

Run the steps in order. When a step is done, set its status here and add a
handover note at the end of this doc.

| Step | What | Status |
| --- | --- | --- |
| 1 | Flutter 3.47.6 and the code generators | Not started |
| 2 | Check the app: tests, macOS rendering, builds | Not started |
| 3 | Raise `sdk:` and reformat | Not started |
| 4 | Clean-ups the upgrade opens up | Not started |
| 5 | Before the November stable: `material_ui` | Not started |

Steps 1 and 3 are separate commits. Step 3 reformats most files, so nothing
else goes in it.

## Step 1: Flutter 3.47.6 and the code generators

**Manual (you):** upgrade the SDK on this Mac. It changes `~/development/flutter`
for every project. `flutter downgrade` goes back.

```bash
flutter upgrade    # newest stable; if that is no longer 3.47.x, check out the tag:
# git -C ~/development/flutter fetch --tags && git -C ~/development/flutter checkout 3.47.6
flutter --version  # expect 3.47.6, Dart 3.13.5
```

1. Branch, e.g. `chore/flutter-3-47`.
2. In `pubspec.yaml`:

   ```yaml
   dependencies:
     freezed_annotation: ^3.1.0   # was ^2.4.0
     json_annotation: ^4.12.0     # was ^4.9.0
   dev_dependencies:
     freezed: ^4.0.2              # was ^2.5.0; needs Dart 3.13
     build_runner: ^2.16.2        # was ^2.4.0
     json_serializable: ^6.14.1   # was ^6.8.0
     mockito: ^5.8.1              # was ^5.4.4
   ```

3. Add `abstract` to the 24 single-variant `@freezed` classes, and `sealed` to
   `Failure` (`lib/domain/entities/failure.dart:9`), which has several
   variants:

   ```dart
   @freezed
   abstract class Entry with _$Entry { ... }
   ```

4. Run `flutter pub get`, then `dart run build_runner build`. Commit the
   regenerated files and the `analysis_options.yaml` edit with the rest.
5. Remove `--delete-conflicting-outputs` from `scripts/app/test.sh:72`,
   `CLAUDE.md` and every other doc or agent file that mentions it.

**Done when:**

- [ ] `flutter --version` shows 3.47.6 and Dart 3.13.5.
- [ ] `dart run build_runner build` finishes, and a second run changes nothing.
- [ ] `flutter analyze` reports no issues.

## Step 2: Check the app

1. Run `scripts/app/test.sh`: format, analyze, generated code, unit and widget
   tests, macOS integration tests.
2. Run the Chrome integration tests: `scripts/app/web/test_chrome.sh`.
3. **By eye (you):** compare Impeller and Skia on macOS, side by side. Use a
   sutta with conjuncts such as ඤ්ජ and ණ්ඩ, footnotes, and search highlights:

   ```bash
   flutter run -d macos                       # Impeller (new default)
   flutter run -d macos --no-enable-impeller  # Skia, for comparison
   ```

4. Check that `flutter build web --release` builds, and that the database
   download still works on a first visit.
5. Check that `flutter build macos --release` builds.

**Done when:**

- [ ] All tests pass. Rerun a failing integration file on its own before
      blaming the upgrade; the full suite is flaky under load.
- [ ] Sinhala text looks right under Impeller, or the opt-out is in with a
      note saying why.
- [ ] The web and macOS release builds succeed.

## Step 3: Raise `sdk:` and reformat

- Set `sdk: ^3.13.0` in `pubspec.yaml`, `packages/wisdom_shared/pubspec.yaml`
  and `static_site_generator/pubspec.yaml`, so there is one format style
  everywhere.
- Run `dart format`. It switches most files to the tall style. One commit,
  with nothing else in it.
- Dart 3.13 forbids `final` or `var` on ordinary parameters. None were found
  on 2026-10-08.
- json_serializable's warning goes away.

**Done when:**

- [ ] `scripts/app/test.sh` passes.
- [ ] The static site output is unchanged. Build into two folders, one before
      and one after this commit, and compare them:

  ```bash
  dart run static_site_generator/bin/generate.dart --root all --out /tmp/site-before
  # ...commit step 3, then:
  dart run static_site_generator/bin/generate.dart --root all --out /tmp/site-after
  diff -rq /tmp/site-before /tmp/site-after   # no output means identical
  ```

## Step 4: Clean-ups

The upgrade doesn't need any of these. Each one can be its own small commit.

- Remove unused packages: `flutter_gen` (`pubspec.yaml:86`; nothing imports
  it) and `cupertino_icons` (`pubspec.yaml:85`; no `CupertinoIcons` used).
- Dot shorthands, in about 180 places in `lib/` (rough count):

  ```dart
  Row(mainAxisAlignment: MainAxisAlignment.center)  // before
  Row(mainAxisAlignment: .center)                   // after
  ```

- `_` instead of `__` in closures: 8 places, e.g.
  `lib/domain/entities/failure.dart:60`.
- Private named parameters instead of `: _x = x` initializers: about 14
  places.
- Now that `Failure` is `sealed`, `userMessage` can use a `switch` expression
  instead of `when`.
- Dart 3.14 (in the next stable) adds `dart migrate --step=cleanup`, which
  applies some of these automatically.

## Step 5: Before the November stable: `material_ui`

Material and Cupertino moved out of the SDK into the `material_ui` and
`cupertino_ui` packages. That's opt-in in 3.47, and the November release
deprecates the old imports. `flutter analyze` fails on info-level issues by
default (`scripts/app/test.sh:66`), so the deprecation warnings would most
likely block deploys.

- `dart fix --apply --code=migrate_design_widgets` rewrites the imports in
  about 90 files. Plain `dart fix --apply` does not include this fix.
- Pin `material_ui` with a caret; the fix may write `any`.
- The three localization delegates in `lib/main.dart:173` become
  `GlobalMaterialLocalizations.delegates`.

## Separate work, not part of this plan

- Riverpod 2 → 3. 2.6.1 works on 3.47 but has had no release since
  2024-10-22. In 3.x, `StateNotifier` and `StateProvider` move to a
  `legacy.dart` import.
- `dartz` has had no release since 2021-12-03. It runs on Dart 3 only through
  pub's compatibility rule for pre-3.0 packages.
- `flutter_lints` 4 → 6.

## Handover notes

None yet.

## Sources

- [What's new in Flutter 3.47](https://flutter.dev/blog/whats-new-in-flutter-3-47)
- [Flutter 3.47.0 release notes](https://docs.flutter.dev/release/release-notes/release-notes-3.47.0)
- [Breaking changes](https://docs.flutter.dev/release/breaking-changes)
- [Flutter stable CHANGELOG (hotfixes)](https://github.com/flutter/flutter/blob/stable/CHANGELOG.md)
- [Dart SDK CHANGELOG](https://github.com/dart-lang/sdk/blob/main/CHANGELOG.md)
- [Migrating to `material_ui` and `cupertino_ui`](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui)
- [Impeller](https://docs.flutter.dev/perf/impeller)
- [UIScene migration](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)
- [Raising the macOS deployment target to 12](https://startdebugging.net/2026/09/raise-a-flutter-macos-apps-minimum-deployment-target-to-macos-12-for-xcode-27/)
- [freezed changelog](https://pub.dev/packages/freezed/changelog)
- [Riverpod 3 migration](https://riverpod.dev/docs/3.0_migration)
