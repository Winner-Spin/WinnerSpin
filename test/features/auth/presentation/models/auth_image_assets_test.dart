import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/presentation/models/auth_image_assets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('shared authentication images are bundled', () async {
    for (final assetPath in [
      AuthImageAssets.emailField,
      AuthImageAssets.musicButton,
      AuthImageAssets.passwordField,
    ]) {
      final data = await rootBundle.load(assetPath);
      expect(data.lengthInBytes, greaterThan(0));
    }
  });
}
