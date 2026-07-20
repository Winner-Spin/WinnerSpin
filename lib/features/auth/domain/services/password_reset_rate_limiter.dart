import '../repositories/auth_repository.dart';

class PasswordResetRateLimiter {
  const PasswordResetRateLimiter._();

  static const Duration cooldown = Duration(days: 1);

  static DateTime? nextAllowedAt({
    required DateTime? lastRequestAt,
    required DateTime now,
  }) {
    if (lastRequestAt == null) return null;
    final nextAllowedAt = lastRequestAt.add(cooldown);
    return now.isBefore(nextAllowedAt) ? nextAllowedAt : null;
  }

  static void ensureAllowed({
    required DateTime? lastRequestAt,
    required DateTime now,
  }) {
    final retryAt = nextAllowedAt(lastRequestAt: lastRequestAt, now: now);
    if (retryAt != null) {
      throw PasswordResetLimitException(retryAt);
    }
  }
}
