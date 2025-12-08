// Basic smoke test placeholder for The Wisdom Project
//
// This file ensures the test infrastructure works. Detailed tests are
// organized by layer in subdirectories:
// - test/domain/     - Use case tests
// - test/data/       - Repository and datasource tests
// - test/presentation/ - Widget tests

import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_data.dart';

void main() {
  group('Test infrastructure', () {
    test('TestData fixtures are accessible', () {
      // Verify test data is properly configured
      expect(TestData.rootNode.nodeKey, equals('sp'));
      expect(TestData.leafNodeWithContent.contentFileId, equals('dn-1'));
      expect(TestData.sampleDocument.fileId, equals('dn-1'));
      expect(TestData.sampleDocument.pageCount, equals(2));
    });

    test('Failure types are properly defined', () {
      expect(TestData.dataLoadFailure.userMessage, contains('Failed to load'));
      expect(TestData.notFoundFailure.userMessage, contains('Not found'));
    });
  });
}
