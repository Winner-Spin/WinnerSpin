import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/firestore_required_version_source.dart';

/// Covers how the `config/appVersion` document is interpreted. The Firestore
/// call itself is exercised by the rules tests, as with the other adapters.
void main() {
  test('reads minimumVersion and storeUrl', () {
    final result = FirestoreRequiredVersionSource.parse({
      'minimumVersion': '1.1.0',
      'storeUrl': 'https://apps.apple.com/app/id6795310235',
    });

    expect(result?.version, '1.1.0');
    expect(result?.storeUrl, 'https://apps.apple.com/app/id6795310235');
  });

  test('storeUrl is optional', () {
    final result = FirestoreRequiredVersionSource.parse({
      'minimumVersion': '2.0.0',
    });

    expect(result?.version, '2.0.0');
    expect(result?.storeUrl, isNull);
  });

  test('returns null for a missing document', () {
    // The state of a fresh project: nothing may block on a missing document.
    expect(FirestoreRequiredVersionSource.parse(null), isNull);
  });

  test('returns null when minimumVersion is unusable', () {
    for (final value in <Object?>[null, '', '   ', 42, true, <String>[]]) {
      expect(
        FirestoreRequiredVersionSource.parse({
          if (value != null) 'minimumVersion': value,
        }),
        isNull,
        reason: 'minimumVersion: $value',
      );
    }
  });

  test('trims surrounding whitespace', () {
    final result = FirestoreRequiredVersionSource.parse({
      'minimumVersion': '  1.4.2  ',
      'storeUrl': '  https://example.com  ',
    });

    expect(result?.version, '1.4.2');
    expect(result?.storeUrl, 'https://example.com');
  });

  test('ignores a blank storeUrl rather than passing it on', () {
    final result = FirestoreRequiredVersionSource.parse({
      'minimumVersion': '1.0.0',
      'storeUrl': '   ',
    });

    expect(result?.storeUrl, isNull);
  });

  test('the document path is the one the rules and docs describe', () {
    expect(FirestoreRequiredVersionSource.collection, 'config');
    expect(FirestoreRequiredVersionSource.document, 'appVersion');
    expect(FirestoreRequiredVersionSource.minimumVersionField, 'minimumVersion');
  });
}
