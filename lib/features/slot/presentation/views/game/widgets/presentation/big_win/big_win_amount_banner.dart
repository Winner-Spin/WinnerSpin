import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../win/win_amount_counter.dart';

class BigWinAmountBanner extends StatelessWidget {
  const BigWinAmountBanner({
    super.key,
    required this.amount,
    required this.duration,
    required this.bannerAssetPath,
    required this.bannerCacheWidth,
    this.skipCountUp = false,
    this.vibrationEnabled = false,
  });

  final double amount;
  final Duration duration;
  final String bannerAssetPath;
  final int bannerCacheWidth;
  final bool skipCountUp;
  final bool vibrationEnabled;

  static final TextStyle _amountStyle = GoogleFonts.outfit(
    color: Colors.white,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    decoration: TextDecoration.none,
    shadows: [
      Shadow(
        color: Colors.black.withValues(alpha: 0.45),
        offset: const Offset(0, 3),
        blurRadius: 6,
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          bannerAssetPath,
          width: 340,
          filterQuality: FilterQuality.medium,
          cacheWidth: bannerCacheWidth,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: WinAmountCounter(
            from: 0,
            to: amount,
            duration: duration,
            forceComplete: skipCountUp,
            vibrationEnabled: vibrationEnabled,
            style: _amountStyle,
          ),
        ),
      ],
    );
  }
}
