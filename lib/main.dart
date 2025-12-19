import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'presentation/screens/reader_screen.dart';
import 'presentation/providers/search_provider.dart';
import 'core/theme/theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences for search history
  final sharedPrefs = await SharedPreferences.getInstance();

  // Quick validation: Check if FTS database exists in assets
  // This is a fast check that doesn't load the entire database
  try {
    await rootBundle.load('assets/databases/bjt-fts.db');
  } catch (e) {
    // Database not found - show error and exit
    runApp(const _DatabaseMissingError());
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        // Provide SharedPreferences for recent searches
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
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
    // Load saved theme preference on startup
    Future.microtask(
      () => ref.read(themeNotifierProvider.notifier).loadSavedTheme(),
    );
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

      // Home screen
      home: const ReaderScreen(),
    );
  }
}
