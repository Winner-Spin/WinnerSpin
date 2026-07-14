import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/models/spin_result.dart';
import '../models/big_win_presentation_rules.dart';
import '../models/game_presentation_timings.dart';
import '../models/spin_result_presentation_rules.dart';
import '../services/big_win_headline_image_provider.dart';
import 'big_win_overlay_controller.dart';

class BigWinPresentationController {
  final BigWinOverlayController _overlayController = BigWinOverlayController();

  bool _shownThisSpin = false;
  bool get shownThisSpin => _shownThisSpin;

  bool _isShowing = false;
  bool get isShowing => _isShowing;

  ImageProvider? _cachedHeadlineImage;

  double _lastSeenLastWinNormal = 0;

  bool get hasActiveOverlay => _overlayController.hasActiveOverlay;

  void resetForNewSpin() {
    _shownThisSpin = false;
  }

  void trackNormalWin({
    required bool isInFreeSpins,
    required double lastWin,
    required SpinResult? Function() result,
    required bool Function() isMounted,
    required void Function(double amount) showBigWin,
  }) {
    if (isInFreeSpins) return;
    if (lastWin > 0 && _lastSeenLastWinNormal == 0) {
      Future.microtask(() {
        if (!isMounted()) return;
        final hasSequence = SpinResultPresentationRules.hasMultiplierSequence(
          result(),
        );
        if (!hasSequence) {
          Future.delayed(GamePresentationTimings.normalBigWinDelay, () {
            if (isMounted()) showBigWin(lastWin);
          });
        }
      });
    }
    _lastSeenLastWinNormal = lastWin;
  }

  void maybeShow({
    required double amount,
    required double betAmount,
    required bool isBusy,
    required OverlayState? overlay,
    required int speedMultiplier,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback onComplete,
  }) {
    if (!isMounted()) return;
    if (_shownThisSpin || _overlayController.hasActiveOverlay) return;
    if (isBusy) return;

    final tier = BigWinPresentationRules.tierForWin(
      amount: amount,
      betAmount: betAmount,
    );
    if (tier == null || overlay == null) return;

    final headlineImage = BigWinHeadlineImageProvider.resolve(
      overlay.context,
      tier,
    );
    final previousHeadlineImage = _cachedHeadlineImage;
    if (previousHeadlineImage != null && previousHeadlineImage != headlineImage) {
      unawaited(previousHeadlineImage.evict());
    }
    _cachedHeadlineImage = headlineImage;
    unawaited(precacheImage(headlineImage, overlay.context));

    setState(() {
      _shownThisSpin = true;
      _isShowing = true;
    });

    _overlayController.show(
      overlay: overlay,
      amount: amount,
      tier: tier,
      headlineImage: headlineImage,
      instantAmount: speedMultiplier >= 3,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      onComplete: () {
        if (!isMounted()) return;
        setState(() => _isShowing = false);
        onComplete();
      },
    );
  }

  void dispose() {
    final headlineImage = _cachedHeadlineImage;
    _cachedHeadlineImage = null;
    if (headlineImage != null) {
      unawaited(headlineImage.evict());
    }
    _overlayController.dispose();
    _isShowing = false;
  }
}
