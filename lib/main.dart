import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'app/app.dart';
import 'features/slot/presentation/views/widgets/multiplier_bomb_animation.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Warm the Lottie cache before the first frame — the bomb composition
  // is ~1.4 MB and parsing it inline on the first multiplier landing
  // causes a noticeable jank. Fire-and-forget so launch isn't blocked.
  unawaited(AssetLottie(MultiplierBombAnimation.assetPath).load());

  runApp(const WinnerSpinApp());
}
