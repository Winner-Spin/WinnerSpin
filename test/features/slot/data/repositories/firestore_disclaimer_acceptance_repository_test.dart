import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/data/repositories/firestore_disclaimer_acceptance_repository.dart';

void main() {
  group('acceptedVersionOf', () {
    test('reads the stored version', () {
      expect(
        FirestoreDisclaimerAcceptanceRepository.acceptedVersionOf({
          'disclaimerVersion': 2,
        }),
        2,
      );
    });

    test('treats a missing record as never accepted', () {
      expect(FirestoreDisclaimerAcceptanceRepository.acceptedVersionOf(null), 0);
      expect(
        FirestoreDisclaimerAcceptanceRepository.acceptedVersionOf(const {}),
        0,
      );
    });

    test('ignores an unusable value', () {
      // A hand-edited document must not read as an acceptance.
      expect(
        FirestoreDisclaimerAcceptanceRepository.acceptedVersionOf(const {
          'disclaimerVersion': 'yes',
        }),
        0,
      );
    });
  });

  test('writes to the field names the security rules allow', () {
    // The rules list these three keys by name; renaming one here without
    // updating firestore.rules would make every write fail in production.
    expect(FirestoreDisclaimerAcceptanceRepository.collection, 'users');
    expect(
      FirestoreDisclaimerAcceptanceRepository.versionField,
      'disclaimerVersion',
    );
    expect(
      FirestoreDisclaimerAcceptanceRepository.acceptedAtField,
      'disclaimerAcceptedAt',
    );
    expect(
      FirestoreDisclaimerAcceptanceRepository.appVersionField,
      'disclaimerAppVersion',
    );
  });
}
