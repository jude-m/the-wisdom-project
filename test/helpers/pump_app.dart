import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/domain/repositories/navigation_tree_repository.dart';
import 'package:the_wisdom_project/domain/repositories/bjt_document_repository.dart';
import 'package:the_wisdom_project/domain/repositories/recent_searches_repository.dart';
import 'package:the_wisdom_project/domain/repositories/text_search_repository.dart';
import 'package:the_wisdom_project/data/datasources/tree_local_datasource.dart';
import 'package:the_wisdom_project/data/datasources/bjt_document_datasource.dart';
import 'package:the_wisdom_project/presentation/providers/navigation_tree_provider.dart';
import 'package:the_wisdom_project/presentation/providers/document_provider.dart';
import 'package:the_wisdom_project/presentation/providers/search_provider.dart';
import 'package:the_wisdom_project/core/localization/l10n/app_localizations.dart';
import 'package:the_wisdom_project/core/storage/key_value_store_provider.dart';

import 'fake_key_value_store.dart';

/// Default overrides every test needs (currently: an in-memory
/// [keyValueStoreProvider]).
///
/// `pumpApp`, `pumpAppWithScaffold`, and `createTestContainer` prepend
/// these automatically — tests that build their own [ProviderScope]
/// directly (e.g. when they need raw widget control) should pass this
/// list as the scope's `overrides`.
///
/// Each call returns a *fresh* in-memory store. Tests that need to share
/// or inspect a store across multiple calls can override
/// [keyValueStoreProvider] again in their per-call `overrides:` —
/// caller-supplied overrides win because they come last.
List<Override> defaultTestOverrides() => [
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
    ];

/// Creates a test wrapper with Riverpod ProviderScope
///
/// Usage:
/// ```dart
/// await tester.pumpApp(
///   MyWidget(),
///   overrides: [
///     navigationTreeRepositoryProvider.overrideWithValue(mockRepository),
///   ],
/// );
/// ```
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped in MaterialApp, Scaffold, and ProviderScope
  /// The Scaffold provides Material ancestor needed by InkWell, etc.
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
    NavigatorObserver? navigatorObserver,
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [...defaultTestOverrides(), ...overrides],
        child: MaterialApp(
          home: Scaffold(body: widget),
          navigatorObservers: [
            if (navigatorObserver != null) navigatorObserver,
          ],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }

  /// Pumps a widget wrapped in Scaffold, MaterialApp and ProviderScope
  Future<void> pumpAppWithScaffold(
    Widget widget, {
    List<Override> overrides = const [],
  }) async {
    await pumpWidget(
      ProviderScope(
        overrides: [...defaultTestOverrides(), ...overrides],
        child: MaterialApp(
          home: Scaffold(body: widget),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}

/// Helper class for creating provider overrides in tests
class TestProviderOverrides {
  TestProviderOverrides._();

  /// Creates an override for the TreeLocalDataSource
  static Override treeDataSource(TreeLocalDataSource dataSource) {
    return treeLocalDataSourceProvider.overrideWithValue(dataSource);
  }

  /// Creates an override for the NavigationTreeRepository
  static Override navigationTreeRepository(
      NavigationTreeRepository repository) {
    return navigationTreeRepositoryProvider.overrideWithValue(repository);
  }

  /// Creates an override for the BJTDocumentDataSource
  static Override bjtDocumentDataSource(BJTDocumentDataSource dataSource) {
    return bjtDocumentDataSourceProvider.overrideWithValue(dataSource);
  }

  /// Creates an override for the BJTDocumentRepository
  static Override bjtDocumentRepository(BJTDocumentRepository repository) {
    return bjtDocumentRepositoryProvider.overrideWithValue(repository);
  }

  /// Creates an override for SharedPreferences
  static Override sharedPreferences(SharedPreferences prefs) {
    return sharedPreferencesProvider.overrideWithValue(prefs);
  }

  /// Creates an override for TextSearchRepository
  static Override textSearchRepository(TextSearchRepository repository) {
    return textSearchRepositoryProvider.overrideWithValue(repository);
  }

  /// Creates an override for RecentSearchesRepository
  static Override recentSearchesRepository(
      RecentSearchesRepository repository) {
    return recentSearchesRepositoryProvider.overrideWithValue(repository);
  }
}

/// Creates a ProviderContainer with common test overrides
///
/// Useful for unit testing providers without widgets:
/// ```dart
/// final container = createTestContainer(
///   overrides: [
///     navigationTreeRepositoryProvider.overrideWithValue(mockRepo),
///   ],
/// );
/// final result = await container.read(navigationTreeProvider.future);
/// ```
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
  ProviderContainer? parent,
}) {
  return ProviderContainer(
    overrides: [...defaultTestOverrides(), ...overrides],
    parent: parent,
  );
}

/// A test widget that provides access to ref for testing providers
class ProviderTestWidget extends ConsumerWidget {
  final Widget child;
  final void Function(WidgetRef ref)? onBuild;

  const ProviderTestWidget({
    super.key,
    required this.child,
    this.onBuild,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onBuild?.call(ref);
    return child;
  }
}
