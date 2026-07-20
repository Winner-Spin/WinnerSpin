import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/auth/domain/services/password_reset_rate_limiter.dart';

void main() {
  final lastRequestAt = DateTime.utc(2026, 7, 19, 10);

  test('blocks a second password reset inside the 24-hour window', () {
    expect(
      () => PasswordResetRateLimiter.ensureAllowed(
        lastRequestAt: lastRequestAt,
        now: lastRequestAt.add(const Duration(hours: 23, minutes: 59)),
      ),
      throwsA(
        isA<PasswordResetLimitException>().having(
          (error) => error.nextAllowedAt,
          'nextAllowedAt',
          DateTime.utc(2026, 7, 20, 10),
        ),
      ),
    );
  });

  test('allows a password reset when 24 hours have passed', () {
    expect(
      () => PasswordResetRateLimiter.ensureAllowed(
        lastRequestAt: lastRequestAt,
        now: lastRequestAt.add(const Duration(days: 1)),
      ),
      returnsNormally,
    );
  });

  test('allows the first password reset request', () {
    expect(
      () => PasswordResetRateLimiter.ensureAllowed(
        lastRequestAt: null,
        now: lastRequestAt,
      ),
      returnsNormally,
    );
  });
}
