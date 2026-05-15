import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';

import 'app/app.dart';
import 'core/audio/app_audio_context.dart';
import 'features/slot/presentation/views/widgets/multiplier_bomb_animation.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAudioContext.configure();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Pre-parse bomb Lottie to avoid first-frame delay on multiplier landing.
  unawaited(AssetLottie(MultiplierBombAnimation.assetPath).load());

  runApp(const WinnerSpinApp());
}
