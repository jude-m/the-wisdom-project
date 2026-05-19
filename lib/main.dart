import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/storage/key_value_store_provider.dart';
import 'core/storage/shared_preferences_key_value_store.dart';
import 'presentation/keyboard/app_shortcuts.dart';
import 'presentation/screens/reader_screen.dart';
import 'presentation/providers/search_provider.dart';
import 'presentation/providers/platform_providers.dart';
import 'presentation/providers/navigation_tree_provider.dart';
import 'presentation/providers/tab_provider.dart'
    show activeTabIndexPersistenceProvider;
import 'presentation/providers/navigator_visibility_provider.dart'
    show navigatorVisiblePersistenceProvider;
import 'presentation/widgets/app/overlay_stack_sync.dart';
import 'presentation/widgets/app/update_available_banner.dart';
import 'core/theme/theme_notifier.dart';

// Conditional import: uses dart:io on native, no-op on web
import 'core/utils/platform_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI-based SQLite for desktop platforms (Windows, Linux)
  // Uses conditional import so dart:io is never referenced on web
  if (!kIsWeb && isDesktopPlatform()) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize SharedPreferences for search history
  final sharedPrefs = await SharedPreferences.getInstance();

  // Quick validation: Check if FTS database exists in assets
  // Skip on web - web uses remote datasources (server has the databases)
  if (!kIsWeb) {
    try {
      await rootBundle.load('assets/databases/bjt-fts.db');
    } catch (e) {
      // Database not found - show error and exit
      runApp(const _DatabaseMissingError());
      return;
    }
  }

  runApp(
    ProviderScope(
      overrides: [
        // Provide SharedPreferences for recent searches
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        // Generic key/value storage backing tab persistence (and future features).
        // Shares the same SharedPreferences instance — no duplicate IO.
        keyValueStoreProvider.overrideWithValue(
          SharedPreferencesKeyValueStore(sharedPrefs),
        ),
        // On web, swap local datasources for remote (HTTP) datasources
        if (kIsWeb) ...getWebOverrides(),
      ],
      child: const MyApp(),
    ),
  );
}

/// Error screen shown when the FTS database is missing
class _DatabaseMissingError extends StatelessWidget {
  const _DatabaseMissingError();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 72,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'App Configuration Error',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const SelectableText(
                      'Critical asset missing:\n\n'
                      '  • assets/databases/bjt-fts.db\n\n'
                      'The FTS database is required for search functionality.\n\n'
                      'Developers: Run "cd tools && npm run generate-fts"\n'
                      'before building the app.',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'This app cannot start without the database.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Load saved preferences on startup
    Future.microtask(() {
      ref.read(themeNotifierProvider.notifier).loadSavedTheme();
      ref.read(fontScaleProvider.notifier).loadSavedScale();
      ref.read(navigationLanguageProvider.notifier).loadSavedLanguage();
      // Instantiate the active-tab persistence listener once so changes to
      // activeTabIndexProvider get written to disk for the rest of the
      // session. Tabs themselves persist via TabsNotifier directly.
      ref.read(activeTabIndexPersistenceProvider);
      // Same pattern for the navigator collapse state.
      ref.read(navigatorVisiblePersistenceProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch current theme
    final themeData = ref.watch(currentThemeDataProvider);

    return MaterialApp(
      title: 'The Wisdom Project',
      debugShowCheckedModeBanner: false,

      // Localization
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('si'), // Sinhala
      ],

      // Theme - Single theme based on user preference
      theme: themeData,

      // Overlay every route with an "update available" notification
      // card. The card sits in a Stack on top of the page content (not
      // a Column above it) — so it never displaces the screen and never
      // double-counts the status-bar inset, regardless of platform.
      // The banner is a no-op when there's no update or when the
      // feature flag is off (see BuildInfo.canCheckForUpdates), so it's
      // safe to keep in the tree unconditionally.
      //
      // `Positioned.fill` is wrapped here (not inside the widget) so
      // UpdateAvailableBanner stays portable — it can also be dropped
      // into an OverlayEntry later without a layout-context change.
      // AppShortcuts installs the top-level Shortcuts/Actions/Focus tree
      // for keyboard handling (ESC, Ctrl/Cmd+F, Ctrl/Cmd+Shift+F, smart copy).
      // OverlayStackSync sits inside it and feeds the LIFO overlay stack that
      // the ESC handler pops from — keeps overlay visibility providers as the
      // single source of truth without each overlay knowing about keyboard.
      builder: (context, child) {
        return AppShortcuts(
          child: OverlayStackSync(
            child: Stack(
              fit: StackFit.expand,
              children: [
                child ?? const SizedBox.shrink(),
                const Positioned.fill(child: UpdateAvailableBanner()),
              ],
            ),
          ),
        );
      },

      // Home screen
      home: const ReaderScreen(),
    );
  }
}
