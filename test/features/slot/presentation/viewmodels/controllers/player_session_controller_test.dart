import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/player_session_controller.dart';

void main() {
  test('hydrates the Firestore email and selected profile avatar', () {
    final controller = PlayerSessionController();

    controller.applyUserData({
      'username': 'Player One',
      'email': 'player@example.com',
      'profileAvatarId': 'heart',
    });

    expect(controller.username, 'Player One');
    expect(controller.email, 'player@example.com');
    expect(controller.profileAvatarId, 'heart');

    controller.dispose();
  });

  test('rejects a non-English stored profile avatar id', () {
    final controller = PlayerSessionController();

    controller.applyUserData({
      'email': 'player@example.com',
      'profileAvatarId': 'unsupported_avatar',
    });

    expect(controller.profileAvatarId, SymbolRegistry.defaultProfileAvatarId);

    controller.dispose();
  });

  test('rejects a multiplier bomb as a stored profile avatar', () {
    final controller = PlayerSessionController();

    controller.applyUserData({
      'email': 'player@example.com',
      'profileAvatarId': 'multi_100x',
    });

    expect(controller.profileAvatarId, SymbolRegistry.defaultProfileAvatarId);

    controller.dispose();
  });
}
