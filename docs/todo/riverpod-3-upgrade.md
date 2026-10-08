# Riverpod 3 upgrade — findings and plan

Investigated 2026-10-08. No code changed yet. Not started.

## Decision

Upgrade `flutter_riverpod` from 2.6.1 to 3.4.3 as a plain version bump, and turn Riverpod's new automatic retry off. The work is mostly mechanical and low risk (measured below). Don't add code generation or `riverpod_lint` yet: the current toolchain blocks both (see "Blocked for now").

## How to use this plan

| Step | What | Size | Status |
| --- | --- | --- | --- |
| 1 | The upgrade itself | M | Not started |
| 2 | Tabs in one notifier | L | Optional |
| 3 | Settings save themselves | S | Optional |
| 4 | Theme and font size load like other settings | S | Optional |
| 5 | Action providers become notifier methods | M | Optional |
| 6 | `riverpod_lint`, maybe code generation | S | Blocked until the Flutter 3.47 upgrade |

Rules:

- Step 1 is one PR on its own branch, cut from `main` after `feat/search-pane-redesign` merges.
- Do it after the [Flutter 3.47 upgrade](flutter-3-47-upgrade-plan.md) has merged, never alongside it. That plan's step 3 reformats most files, so a Riverpod branch open at the same time would conflict on nearly every file it touches. Flutter goes first because it has a deadline (the November stable release). 3.4.3 works on both SDKs: it needs Dart ≥ 3.12, and Flutter 3.47.6's `flutter_test` pins `test_api` 0.7.12, inside Riverpod's `^0.7.0`.
- Steps 2–5 are separate PRs after step 1. Each is optional.
- Step 1 has to edit some existing tests (imports, retry, one double override). The upgrade forces these edits, but CLAUDE.md says tests aren't changed without the user's OK, so ask before starting. Write no new tests; a separate agent does that.
- When a step is done, set its status and add a handover note at the end of this doc.

## Findings (measured 2026-10-08)

### Versions

- Now: `flutter_riverpod` 2.6.1 (2024-10-22), the last 2.x release. It gets no more fixes.
- Latest: 3.4.3 (2026-09-03). It needs Dart ≥ 3.12; we have 3.12.1.
- A `pub get` dry run changes only four packages: `flutter_riverpod`, `riverpod`, and two small new ones, `listen` and `uuid`. Freezed, analyzer, mockito and drift stay where they are.
- Riverpod's main branch is still 3.4.3 (plus unreleased fixes), with no 4.0 in development. The "legacy" providers carry no deprecation.

The app has 116 providers: 67 `Provider`, 17 `StateNotifierProvider` (15 notifier classes), 16 `StateProvider`, 11 `FutureProvider`, and 5 family/autoDispose `Provider`s. No code generation.

### What breaks when compiling

On a copy of `lib/`, `test/` and `integration_test/`, the analyzer went from 0 issues to 425 errors after the bump. Four mechanical fixes bring it back to "No issues found!": 40 files, about 70 lines.

| Fix | Where |
| --- | --- |
| `StateProvider`, `StateNotifierProvider`, `StateNotifier` and `StateController` moved to `package:flutter_riverpod/legacy.dart` | 26 files |
| `AsyncValue.valueOrNull` was removed: use `.value` (in 3.x `.value` is null on error, as `valueOrNull` was) | 12 places |
| The `Override` type is no longer exported by `flutter_riverpod.dart`: import it from `package:flutter_riverpod/misc.dart` | 8 test files |
| `RemoveListener` (a `state_notifier` type) is no longer exported: use `void Function()` | `lib/presentation/providers/tab_provider.dart:40` |

### What changes at runtime

Checked by running one script on both versions:

| Check | 2.6.1 | 3.4.3 |
| --- | --- | --- |
| `FutureProvider` that throws an `Exception` | error after 3 ms | still *loading* after 3 s, rebuilt 4 times |
| Reading a sync provider that throws | `StateError` | `ProviderException` |
| `StateProvider<String?>` set to an equal string twice | 2 notifications | 1 notification |
| `Provider<void>` persistence listener started by one `read` | sees every change | sees every change |

**1. Automatic retry: must turn off.** A provider that throws is retried up to 10 times, waiting 200 ms and doubling up to 6.4 s, about 38 s in total. Dart `Error`s and other providers' failures are not retried. **While a provider retries, it reports loading, not error.** All 11 `FutureProvider`s turn a `Failure` into `throw Exception(failure.userMessage)`, which is exactly what gets retried. So:

- A failed load shows a spinner for about 38 s before the error, and re-runs the DB query or JSON parse 10 times.
- `await ref.read(sitePlanProvider.future)` (deep links) and `readerUnitResolverProvider.future` (tabs) wait the whole time.
- Our data is all local (bundled DBs, assets), so a failed load fails again. Retrying only adds delay.

**2. Overriding one provider twice now throws:** `AssertionError: Tried to override a provider twice within the same container` (debug mode, so in every test). `test/presentation/widgets/settings_menu_button_test.dart:109` passes `keyValueStoreProvider` to `createTestContainer`, which already overrides it. The note in `test/helpers/pump_app.dart` that "caller-supplied overrides win because they come last" stops being true.

**3. Tests that check failure screens hit the retry.** Each of these fails a `FutureProvider` with an `Exception`, so it would show a spinner first and call its mock 11 times:

- `test/presentation/widgets/multi_pane_reader_widget_test.dart` (via `pumpApp`)
- `test/presentation/widgets/tree_navigator_widget_test.dart` (via `pumpApp`)
- `test/presentation/widgets/dictionary/dictionary_bottom_sheet_test.dart` (own `ProviderScope`)
- `test/presentation/widgets/common/status_message_view_panels_test.dart` (own `ProviderScope`)

`deep_link_provider_test.dart` is not affected: its fakes throw `StateError`, and retry skips Dart `Error`s.

**4. Checked and harmless:**

- **`ProviderException` wrapping.** Every `catch` in `lib/presentation` is untyped. `AsyncValue.error` and `.future` keep the original error.
- **`==` filtering.** `StateNotifier`s keep their old "notify unless identical" rule, and `Provider` already used `==`. `StateProvider` now uses `==`, so setting an equal String or record twice notifies once. The only visible effect: tapping the same dictionary word again no longer moves the sheet to the top of the ESC stack.
- **Pausing hidden widgets.** 3.x pauses `ref.watch` in widgets whose `TickerMode` is off. Flutter's `IndexedStack` (`app_shell.dart`) keeps hidden sections' tickers on, so they aren't paused. Only the Research pane's nested navigator is affected.
- **Dead `Ref`s.** 3.x throws `UnmountedRefException` when a disposed `Ref` is used, and a provider gets a new `Ref` each time it rebuilds. None of the 15 function-valued providers (`Provider<... Function(...)>`) rebuild at runtime: the only one that watches anything watches `linkBaseUrlProvider`, a build-time constant. No `ConsumerState.dispose()` uses `ref`.
- **The two persistence providers that `main.dart` reads once** still receive every change (tested).

### Performance

Benchmarked on both versions as a compiled release build, best of 5 runs (µs = millionths of a second):

| Operation | 2.6.1 | 3.4.3 |
| --- | --- | --- |
| `read` | 0.04 µs | 0.14 µs |
| one state update (4 listeners) | 0.2 µs | 0.85 µs |
| an update through 30 chained providers | 11 µs | 64 µs |
| create + dispose one family instance | 0.9 µs | 2.1 µs |

3.x is 2–6× slower per operation, but these are microseconds. A tab switch passes through roughly 20–40 providers, about 0.1 ms against an 8–16 ms frame. Scroll saving is debounced, so no provider updates every frame. There's no visible effect; leaving retry on would be the real cost.

### Benefits

- **A maintained version.** 2.x is frozen; fixes land only in 3.x.
- **A Riverpod tab in Flutter DevTools** for inspecting providers live. 3.x ships it; 2.6.1 doesn't.
- **Simpler tests.** `ProviderContainer.test()` disposes itself (the tests create 38 containers by hand and call `dispose` 39 times). `tester.container()` replaces `ProviderScope.containerOf(...)` lookups.
- **`ref.mounted`**, a safe check after an `await` inside a notifier.
- **It unlocks step 6.**
- **Not useful here:** offline persistence and mutations (experimental), and pausing (our layout doesn't trigger it).

### Blocked for now

- `riverpod_lint` 3.1.9 needs Dart ≥ 3.13.
- `riverpod_generator` 4.0.9 needs `freezed_annotation ^3`; the pub solver refuses it with our Freezed 2.
- The [Flutter 3.47 upgrade](flutter-3-47-upgrade-plan.md) brings Dart 3.13.5 and Freezed 4 (`freezed_annotation` 3.1), which removes both blocks. Re-check the resolution then.

## Step 1 — The upgrade

1. In `pubspec.yaml`: `flutter_riverpod: ^3.4.3`.
2. Add `import 'package:flutter_riverpod/legacy.dart';` to every file that names `StateNotifier`, `StateNotifierProvider`, `StateProvider` or `StateController` (the analyzer lists them). Drop the `flutter_riverpod.dart` import wherever it then shows as unused.
3. Rename `.valueOrNull` to `.value`. Find them with `grep -rn valueOrNull lib integration_test`.
4. Wherever `Override` is named as a type (`test/helpers/pump_app.dart`, `integration_test/test_overrides.dart`, a few tests), add `import 'package:flutter_riverpod/misc.dart' show Override;`.
5. In `lib/presentation/providers/tab_provider.dart:40`: `late final void Function() _removeStateListener;`
6. Turn retry off at the root, in `lib/main.dart`:

   ```dart
   runApp(
     ProviderScope(
       // All our data is local (bundled DBs, assets): a failed load fails
       // again. Show the error at once instead of retrying behind a spinner.
       retry: (retryCount, error) => null,
       overrides: [...],
       child: const MyApp(),
     ),
   );
   ```

7. Make the tests match:
   - Pass the same `retry:` to the `ProviderScope`s in `pumpApp` / `pumpAppWithScaffold` and to the `ProviderContainer` in `createTestContainer` (`test/helpers/pump_app.dart`).
   - Do the same in the two tests that build their own scope (`dictionary_bottom_sheet_test.dart`, `status_message_view_panels_test.dart`), and in the integration-test scopes so they behave like the app.
   - Fix `settings_menu_button_test.dart:109`: build its own `ProviderContainer` (with only its in-memory store) instead of calling `createTestContainer`. Reword the "caller-supplied overrides win" note in `pump_app.dart`.

   ```dart
   // Riverpod 3 retries failing providers for ~38 s by default. The app
   // turns that off (main.dart), so tests match it.
   Duration? noRetry(int retryCount, Object error) => null;
   ```

8. Run `flutter analyze`, then `flutter test`, then the integration tests on macOS (`-d macos`). Watch for:
   - a test hanging on a spinner: retry is still on somewhere;
   - `Tried to override a provider twice`;
   - `UnmountedRefException` after a test ends: a notifier used its `Ref` after an `await`.
9. Run the app (macOS, then web). Open and close tabs, restart, and check that the active tab and the navigator's open/closed state come back. Also try the dictionary sheet, a deep link and Research.

**Done when** the analyzer is clean, all suites pass and the smoke run is fine. The PR says which tests changed and why.

## Steps 2–5 — Optional simplifications

The upgrade doesn't simplify anything by itself. But `Notifier` (available since Riverpod 2.0) is now the main style, so these become natural. They're ordered by payoff.

### Step 2 — Tabs in one notifier (L)

Tab state lives in five places: `tabsProvider`, `activeTabIndexProvider`, `inPageSearchStatesProvider` and `ftsHighlightProvider` (both maps keyed by tab *index*), and `activeTabIndexPersistenceProvider`. `closeTabProvider` (`lib/presentation/providers/tab_lifecycle_provider.dart`) keeps them in sync by hand. It re-numbers both maps, and it sets the index to `-1` and back "to force the listener to fire".

Give each tab a stable id. Let one `Notifier` own the tab list and the active tab, and key per-tab state by tab id. The re-indexing, the `-1` flip and the separate persistence provider all go away.

### Step 3 — Settings save themselves (S)

`navigatorVisibleProvider` and `activeTabIndexProvider` each have a separate `Provider<void>` that writes changes to disk, and `main.dart` must `read` both at startup to keep them alive. A `Notifier` can save its own changes:

```dart
class NavigatorVisibleNotifier extends Notifier<bool> {
  @override
  bool build() {
    final store = ref.read(keyValueStoreProvider);
    // Save every change. No extra provider, nothing to start in main.dart.
    listenSelf((_, visible) =>
        store.setInt(StorageKeys.navigatorVisible, visible ? 1 : 0));
    // Nothing saved yet (first launch) means visible.
    return (store.getInt(StorageKeys.navigatorVisible) ?? 1) != 0;
  }

  void toggle() => state = !state;
}

final navigatorVisibleProvider =
    NotifierProvider<NavigatorVisibleNotifier, bool>(NavigatorVisibleNotifier.new);
```

Callers switch from `ref.read(navigatorVisibleProvider.notifier).state = x` to methods such as `toggle()`. If step 2 is done, the active tab's saving moves into that notifier.

### Step 4 — Theme and font size load like other settings (S)

`ThemeNotifier` and `FontScaleNotifier` load late: `main.dart` calls `loadSavedTheme()` / `loadSavedScale()` in a startup microtask, and they call `SharedPreferences.getInstance()` themselves. Every other setting reads `keyValueStoreProvider` straight away, in its constructor. Make these two match and delete the two calls in `main.dart`. This also closes the TODO at the top of `lib/core/theme/theme_notifier.dart`.

### Step 5 — Action providers become notifier methods (M)

Fifteen providers only hold a function (`Provider<... Function(...)>`), for example `closeTabProvider`, `switchTabProvider`, `openTabFromNodeKeyProvider`, `selectNodeProvider` and `toggleNodeExpansionProvider`. Each action belongs on the notifier that owns the state it changes. The tab ones are best done together with step 2.

### Not worth doing

Converting the 16 simple `StateProvider`s to `Notifier` classes. That adds a class per value, and the legacy import is fine.

## Step 6 — Later

- `riverpod_lint`, once the Flutter 3.47 upgrade (Dart 3.13.5) has landed.
- Code generation (`riverpod_generator`): possible once that upgrade's Freezed 4 is in, but probably not worth it. It would turn every provider into an annotated function or class.

## How the findings were checked

- **Compile:** copied `lib/`, `test/`, `integration_test/` and `packages/wisdom_shared` to a scratch folder. Analyzed on 2.6.1 (clean), bumped the version, analyzed, fixed, analyzed again.
- **Behaviour:** ran a small pure-Dart script against `riverpod` 2.6.1 and 3.4.3, and read the 3.4.3 source (`ProviderContainer.defaultRetry`, `ProviderElement.triggerRetry`, the duplicate-override check, and widget pausing in `consumer.dart`).
- **Benchmark:** `dart compile exe -Ddart.vm.product=true`, best of 5 runs, repeated three times.
- `pub get` had to run outside the Bash sandbox, because the sandbox's proxy breaks Dart's TLS.

## Handover notes

None yet.

## Sources

- [Migrating from 2.0 to 3.0](https://riverpod.dev/docs/3.0_migration)
- [What's new in Riverpod 3.0](https://riverpod.dev/docs/whats_new)
- [flutter_riverpod changelog](https://pub.dev/packages/flutter_riverpod/changelog)
- [riverpod changelog](https://pub.dev/packages/riverpod/changelog)
