import 'package:flutter/material.dart';

import '../../../auth/presentation/views/login_screen.dart';
import '../viewmodels/game_viewmodel.dart';
import '../views/auto_play/auto_play_settings_screen.dart';
import '../views/buy_freespins/buy_freespins_confirm_screen.dart';
import '../views/rules/game_rules_screen.dart';
import '../views/settings/system_settings_screen.dart';
import '../views/shared/widgets/spring_popup_transition.dart';

class GameScreenNavigation {
  const GameScreenNavigation._();

  static void showAutoPlaySettings({
    required BuildContext context,
    required GameViewModel viewModel,
  }) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Auto Play Settings',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          AutoPlaySettingsScreen(viewModel: viewModel),
      transitionBuilder: (context, anim, _, child) {
        return buildSpringPopupTransition(anim, child);
      },
    );
  }

  static void showGameRules({
    required BuildContext context,
    required double betAmount,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, animation, child) =>
            GameRulesScreen(betAmount: betAmount),
        transitionsBuilder: (context, anim, animation, child) {
          return buildSpringPopupTransition(anim, child);
        },
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
  }

  static void showSystemSettings({
    required BuildContext context,
    required GameViewModel viewModel,
  }) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          SystemSettingsScreen(viewModel: viewModel),
      transitionBuilder: (context, anim, _, child) {
        return buildSpringPopupTransition(anim, child);
      },
    );
  }

  static Future<bool> promptBuyFreeSpinsConfirm({
    required BuildContext context,
    required int spinCount,
    required double price,
  }) async {
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) =>
            BuyFreeSpinsConfirmScreen(spinCount: spinCount, price: price),
        transitionsBuilder: (_, anim, _, child) =>
            buildSpringPopupTransition(anim, child),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
    return confirmed == true;
  }

  static void handleLogout({
    required BuildContext context,
    required GameViewModel viewModel,
    required bool isMounted,
  }) {
    if (!isMounted || !viewModel.loggedOut) return;
    viewModel.resetLoggedOut();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }
}
