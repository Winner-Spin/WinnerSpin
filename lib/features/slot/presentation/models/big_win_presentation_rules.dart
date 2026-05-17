import '../../domain/models/spin_result.dart';
import 'win_tier.dart';

class BigWinPresentationRules {
  const BigWinPresentationRules._();

  static WinTier? tierForWin({
    required double amount,
    required double betAmount,
  }) {
    if (amount <= 0 || betAmount <= 0) return null;
    return WinTier.forMultiplier(amount / betAmount);
  }

  static bool hasEligibleBigWin({
    required SpinResult? result,
    required bool isCurrentSpinFromBuy,
    required double betAmount,
  }) {
    if (result == null || isCurrentSpinFromBuy) return false;
    return tierForWin(amount: result.totalWin, betAmount: betAmount) != null;
  }
}
