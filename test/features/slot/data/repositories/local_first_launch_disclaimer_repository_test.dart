import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/data/repositories/local_first_launch_disclaimer_repository.dart';
import 'package:winner_spin/features/slot/domain/repositories/first_launch_disclaimer_repository.dart';

void main() {
  test('counts the pre-versioning marker as version 1', () {
    // Builds before the version was recorded wrote the literal `seen`. Those
    // players did accept the text that shipped as version 1, so re-prompting
    // them would be wrong.
    expect(LocalFirstLaunchDisclaimerRepository.versionOf('seen'), 1);
  });

  test('reads a recorded version', () {
    expect(LocalFirstLaunchDisclaimerRepository.versionOf('3'), 3);
    expect(LocalFirstLaunchDisclaimerRepository.versionOf(' 2 \n'), 2);
  });

  test('treats unreadable contents as never accepted', () {
    expect(LocalFirstLaunchDisclaimerRepository.versionOf(''), 0);
    expect(LocalFirstLaunchDisclaimerRepository.versionOf('garbage'), 0);
  });

  test('the shipped version is a real version', () {
    // `0` would make every stored acceptance count, including a corrupt file.
    expect(kDisclaimerVersion, greaterThan(0));
  });
}
