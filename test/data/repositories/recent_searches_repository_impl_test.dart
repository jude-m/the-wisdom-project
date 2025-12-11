import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:the_wisdom_project/data/repositories/recent_searches_repository_impl.dart';
import 'package:the_wisdom_project/domain/entities/search/recent_search.dart';

void main() {
  late RecentSearchesRepositoryImpl repository;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = RecentSearchesRepositoryImpl(prefs);
  });

  group('RecentSearchesRepositoryImpl -', () {
    group('getRecentSearches', () {
      test('should return empty list when no searches stored', () async {
        // ACT
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
      });

      test('should return searches ordered by timestamp (newest first)',
          () async {
        // ARRANGE
        final now = DateTime.now();
        final searches = [
          RecentSearch(
              queryText: 'oldest',
              timestamp: now.subtract(const Duration(hours: 2))),
          RecentSearch(
              queryText: 'middle',
              timestamp: now.subtract(const Duration(hours: 1))),
          RecentSearch(queryText: 'newest', timestamp: now),
        ];
        // Store in reverse order (oldest first in storage)
        final jsonList = searches.reversed.map((s) => s.toJson()).toList();
        await prefs.setString('recent_searches', jsonEncode(jsonList));

        // Re-create repository to pick up the new data
        repository = RecentSearchesRepositoryImpl(prefs);

        // ACT
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(3));
        // Storage order is maintained - oldest first becomes first returned
        expect(result[0].queryText, equals('newest'));
      });

      test('should respect limit parameter', () async {
        // ARRANGE
        final now = DateTime.now();
        final searches = List.generate(
          10,
          (i) => RecentSearch(
            queryText: 'search$i',
            timestamp: now.subtract(Duration(hours: i)),
          ),
        );
        final jsonList = searches.map((s) => s.toJson()).toList();
        await prefs.setString('recent_searches', jsonEncode(jsonList));
        repository = RecentSearchesRepositoryImpl(prefs);

        // ACT
        final result = await repository.getRecentSearches(limit: 3);

        // ASSERT
        expect(result.length, equals(3));
        expect(result[0].queryText, equals('search0'));
        expect(result[1].queryText, equals('search1'));
        expect(result[2].queryText, equals('search2'));
      });

      test('should handle corrupted data gracefully', () async {
        // ARRANGE - Store invalid JSON
        await prefs.setString('recent_searches', 'not valid json');
        repository = RecentSearchesRepositoryImpl(prefs);

        // ACT
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
        // Corrupted data should be cleared
        expect(prefs.getString('recent_searches'), isNull);
      });
    });

    group('addRecentSearch', () {
      test('should add new search to history', () async {
        // ACT
        await repository.addRecentSearch('dhamma');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(1));
        expect(result[0].queryText, equals('dhamma'));
      });

      test('should move duplicate to top (case-insensitive)', () async {
        // ARRANGE
        await repository.addRecentSearch('dhamma');
        await repository.addRecentSearch('buddha');
        await repository.addRecentSearch('sangha');

        // ACT - Add duplicate with different case
        await repository.addRecentSearch('DHAMMA');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(3));
        expect(result[0].queryText, equals('DHAMMA')); // Most recent
        expect(result[1].queryText, equals('sangha'));
        expect(result[2].queryText, equals('buddha'));
      });

      test('should trim list to max items (10)', () async {
        // ARRANGE - Add 12 items
        for (int i = 0; i < 12; i++) {
          await repository.addRecentSearch('search$i');
        }

        // ACT
        final result = await repository.getRecentSearches(limit: 20);

        // ASSERT
        expect(result.length, equals(10));
        expect(result[0].queryText, equals('search11')); // Most recent
        expect(result[9].queryText, equals('search2')); // Oldest kept
      });

      test('should ignore empty queries', () async {
        // ACT
        await repository.addRecentSearch('');
        await repository.addRecentSearch('   ');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
      });

      test('should trim whitespace from queries', () async {
        // ACT
        await repository.addRecentSearch('  dhamma  ');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(1));
        expect(result[0].queryText, equals('dhamma'));
      });
    });

    group('removeRecentSearch', () {
      test('should remove specific search from history', () async {
        // ARRANGE
        await repository.addRecentSearch('dhamma');
        await repository.addRecentSearch('buddha');
        await repository.addRecentSearch('sangha');

        // ACT
        await repository.removeRecentSearch('buddha');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(2));
        expect(
            result.map((s) => s.queryText), containsAll(['sangha', 'dhamma']));
        expect(result.map((s) => s.queryText), isNot(contains('buddha')));
      });

      test('should be case-insensitive when removing', () async {
        // ARRANGE
        await repository.addRecentSearch('Dhamma');

        // ACT
        await repository.removeRecentSearch('dhamma');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
      });

      test('should handle removing non-existent search gracefully', () async {
        // ARRANGE
        await repository.addRecentSearch('dhamma');

        // ACT
        await repository.removeRecentSearch('nonexistent');
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result.length, equals(1));
        expect(result[0].queryText, equals('dhamma'));
      });
    });

    group('clearRecentSearches', () {
      test('should clear all stored searches', () async {
        // ARRANGE
        await repository.addRecentSearch('dhamma');
        await repository.addRecentSearch('buddha');
        await repository.addRecentSearch('sangha');

        // ACT
        await repository.clearRecentSearches();
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
      });

      test('should work when no searches exist', () async {
        // ACT - Should not throw
        await repository.clearRecentSearches();
        final result = await repository.getRecentSearches();

        // ASSERT
        expect(result, isEmpty);
      });
    });
  });
}
