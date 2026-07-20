import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/slot/domain/models/game_history_entry.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/repositories/game_history_repository.dart';
import 'package:winner_spin/features/slot/domain/repositories/pool_repository.dart';
import 'package:winner_spin/features/slot/presentation/audio/game_music_service.dart';
import 'package:winner_spin/features/slot/presentation/audio/ui_click_sound.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/game_viewmodel.dart';
import 'package:winner_spin/features/slot/presentation/views/profile/profile_screen.dart';

void main() {
  testWidgets('selects an avatar and sends reset to the Firestore email', (
    tester,
  ) async {
    UiClickSound.enabled = false;
    final authRepository = _ProfileAuthRepository();
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );
    await viewModel.fetchUserData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(viewModel: viewModel, onClose: () {}),
        ),
      ),
    );

    expect(find.text('MY PROFILE'), findsOneWidget);
    expect(find.text('SELECT AVATAR'), findsNothing);
    expect(find.text('player@example.com'), findsWidgets);
    expect(find.byKey(const ValueKey('select-avatar-button')), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Avatar heart'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('select-avatar-button')));
    await tester.pumpAndSettle();

    expect(find.text('SELECT AVATAR'), findsOneWidget);
    expect(find.text('MY PROFILE'), findsNothing);
    expect(find.text('player@example.com'), findsNothing);
    expect(find.text('RESET PASSWORD'), findsNothing);
    expect(find.bySemanticsLabel('Avatar multi_2x'), findsNothing);
    expect(find.text('PINK BEAR'), findsOneWidget);

    final heartAvatar = find.byKey(const ValueKey('profile-avatar-heart'));
    await tester.drag(
      find.byKey(const ValueKey('profile-avatar-list')),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Avatar heart')), findsOneWidget);
    expect(find.text('HEART'), findsOneWidget);
    await tester.tap(heartAvatar);
    await tester.pumpAndSettle();
    expect(authRepository.savedAvatarId, 'heart');
    expect(find.text('SELECT AVATAR'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-header-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('MY PROFILE'), findsOneWidget);
    expect(find.text('SELECT AVATAR'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    expect(authRepository.passwordResetEmail, 'player@example.com');
    expect(find.textContaining('once every 24 hours'), findsOneWidget);

    viewModel.dispose();
  });

  testWidgets('shows the Firestore daily reset limit to the player', (
    tester,
  ) async {
    UiClickSound.enabled = false;
    final authRepository = _ProfileAuthRepository(
      passwordResetLimit: DateTime.now().add(const Duration(hours: 12)),
    );
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );
    await viewModel.fetchUserData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(viewModel: viewModel, onClose: () {}),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RESET PASSWORD'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Only one password reset'), findsOneWidget);
    expect(authRepository.passwordResetEmail, isNull);

    viewModel.dispose();
  });

  testWidgets('shows delete above logout and confirms account deletion', (
    tester,
  ) async {
    UiClickSound.enabled = false;
    final authRepository = _ProfileAuthRepository();
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );
    await viewModel.fetchUserData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(viewModel: viewModel, onClose: () {}),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();

    final deleteButton = find.byKey(const ValueKey('delete-account-button'));
    final logoutButton = find.byKey(const ValueKey('log-out-button'));
    expect(deleteButton, findsOneWidget);
    expect(logoutButton, findsOneWidget);
    await tester.ensureVisible(logoutButton);
    await tester.pump();
    expect(
      tester.getTopLeft(deleteButton).dy,
      lessThan(tester.getTopLeft(logoutButton).dy),
    );

    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    expect(find.text('DELETE ACCOUNT?'), findsOneWidget);
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    expect(authRepository.deleteAccountCalls, 0);

    await tester.tap(
      find.byKey(const ValueKey('confirm-delete-account-button')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(authRepository.deleteAccountCalls, 1);
    expect(viewModel.loggedOut, isTrue);

    viewModel.dispose();
  });

  testWidgets('logs out from the bottom of the account section', (
    tester,
  ) async {
    UiClickSound.enabled = false;
    final authRepository = _ProfileAuthRepository();
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );
    await viewModel.fetchUserData();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileScreen(viewModel: viewModel, onClose: () {}),
        ),
      ),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    final logoutButton = find.byKey(const ValueKey('log-out-button'));
    await tester.ensureVisible(logoutButton);
    await tester.pump();
    await tester.tap(logoutButton);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(authRepository.signOutCalls, 1);
    expect(viewModel.loggedOut, isTrue);

    viewModel.dispose();
  });

  test('forwards account deletion through the game view model', () async {
    final authRepository = _ProfileAuthRepository();
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );

    await viewModel.deleteAccount();

    expect(authRepository.deleteAccountCalls, 1);
    expect(viewModel.loggedOut, isTrue);
    viewModel.dispose();
  });

  test('rejects a stored non-English avatar id', () async {
    final authRepository = _ProfileAuthRepository();
    authRepository._userData['profileAvatarId'] = 'unsupported_avatar';
    final viewModel = GameViewModel(
      authRepository: authRepository,
      poolRepository: _ProfilePoolRepository(),
      gameHistoryRepository: _ProfileHistoryRepository(),
      musicService: _SilentGameMusicService(),
    );

    await viewModel.fetchUserData();

    expect(viewModel.profileAvatarId, 'pink_bear');
    expect(authRepository.savedAvatarId, isNull);
    viewModel.dispose();
  });
}

class _ProfileAuthRepository implements AuthRepository {
  _ProfileAuthRepository({this.passwordResetLimit});

  final DateTime? passwordResetLimit;
  String? savedAvatarId;
  String? passwordResetEmail;
  int signOutCalls = 0;
  int deleteAccountCalls = 0;

  final Map<String, dynamic> _userData = {
    'username': 'Player One',
    'email': 'player@example.com',
    'profileAvatarId': 'pink_bear',
    'userBalance': 10000.0,
    'freeSpinsRemaining': 0,
  };

  @override
  String? get currentUserId => 'user-1';

  @override
  String? get currentUserEmail => 'player@example.com';

  @override
  bool get currentUserEmailVerified => true;

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async => _userData;

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) async {
    savedAvatarId = avatarId;
    _userData['profileAvatarId'] = avatarId;
  }

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {
    final limit = passwordResetLimit;
    if (limit != null) throw PasswordResetLimitException(limit);
    passwordResetEmail = email;
  }

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      const Stream.empty();

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) async {}

  @override
  Future<String?> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
  }

  @override
  Future<void> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerificationLink() => throw UnimplementedError();

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) => throw UnimplementedError();
}

class _ProfilePoolRepository implements PoolRepository {
  @override
  Future<PoolState> load(String uid) async => PoolState();

  @override
  Future<void> save(String uid, PoolState state) async {}
}

class _ProfileHistoryRepository implements GameHistoryRepository {
  @override
  Future<List<GameHistoryEntry>> load(String userId) async => const [];

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async {}
}

class _SilentGameMusicService extends GameMusicService {
  @override
  Future<void> initialize({required bool playWhenReady}) async {}

  @override
  Future<void> dispose() async {}
}
