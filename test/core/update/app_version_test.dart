import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_version.dart';

void main() {
  test('compares segments numerically, not as text', () {
    final ten = AppVersion.tryParse('1.10.0')!;
    final nine = AppVersion.tryParse('1.9.0')!;

    // String comparison would put '1.10.0' before '1.9.0'.
    expect(ten > nine, isTrue);
    expect(nine < ten, isTrue);
  });

  test('treats missing trailing segments as zero', () {
    expect(AppVersion.tryParse('1.2'), AppVersion.tryParse('1.2.0'));
    expect(AppVersion.tryParse('1'), AppVersion.tryParse('1.0.0'));
    expect(
      AppVersion.tryParse('1.2.0')!.compareTo(AppVersion.tryParse('1.2.1')!),
      lessThan(0),
    );
  });

  test('ignores build numbers and pre-release suffixes', () {
    expect(AppVersion.tryParse('1.0.0+42'), AppVersion.tryParse('1.0.0'));
    expect(AppVersion.tryParse('2.1.0-beta.3'), AppVersion.tryParse('2.1.0'));
    expect(AppVersion.tryParse('  1.4.2  '), AppVersion.tryParse('1.4.2'));
  });

  test('returns null for input that cannot be trusted', () {
    for (final raw in [null, '', '   ', 'abc', '1.x.0', '1..0', '-1.0']) {
      expect(AppVersion.tryParse(raw), isNull, reason: 'input: $raw');
    }
  });

  test('orders a realistic release sequence', () {
    final versions = ['1.0.0', '1.0.1', '1.1.0', '1.10.0', '2.0.0']
        .map((v) => AppVersion.tryParse(v)!)
        .toList();

    for (var i = 1; i < versions.length; i++) {
      expect(
        versions[i] > versions[i - 1],
        isTrue,
        reason: '${versions[i]} should outrank ${versions[i - 1]}',
      );
    }
  });
}
