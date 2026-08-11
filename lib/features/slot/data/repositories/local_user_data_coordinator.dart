import 'dart:async';

/// Serializes local file access per uid and permanently tombstones deleted ids.
class LocalUserDataCoordinator {
  LocalUserDataCoordinator();

  static final LocalUserDataCoordinator shared = LocalUserDataCoordinator();

  final Map<String, Future<void>> _tails = {};
  final Set<String> _blockedUserIds = {};

  Future<T> run<T>(
    String userId,
    Future<T> Function() operation, {
    required T Function() whenBlocked,
  }) {
    if (_blockedUserIds.contains(userId)) {
      return Future<T>.value(whenBlocked());
    }

    final previous = _tails[userId] ?? Future<void>.value();
    final result = previous.then((_) => operation());
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[userId] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[userId], tail)) _tails.remove(userId);
      }),
    );
    return result;
  }

  Future<void> blockAndDrain(String userId) {
    _blockedUserIds.add(userId);
    return _tails[userId] ?? Future<void>.value();
  }

  Future<void> erase(String userId, Future<void> Function() cleanup) async {
    await blockAndDrain(userId);
    await cleanup();
  }
}
