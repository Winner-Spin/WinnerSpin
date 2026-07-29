import 'package:flutter/material.dart';

import '../../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../../../core/update/app_build_info.dart';
import '../../../data/repositories/firestore_disclaimer_acceptance_repository.dart';
import '../../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../../services/game_background_image_provider.dart';
import '../../viewmodels/controllers/disclaimer_gate_controller.dart';
import 'game_screen.dart';
import 'widgets/presentation/dialogs/first_launch_disclaimer_dialog.dart';

/// Stands between sign-in and the game: the game is not built at all until the
/// disclaimer has been accepted.
///
/// Deliberately a gate rather than a dialog over the game. A dialog leaves the
/// game mounted underneath — loading data, starting music, one stray dismissal
/// away from being playable. Here the player either accepts or sees nothing but
/// the notice.
class DisclaimerGate extends StatefulWidget {
  const DisclaimerGate({
    super.key,
    this.authRepository,
    this.localRepository,
    this.acceptanceRepository,
    this.child,
  });

  final AuthRepository? authRepository;
  final FirstLaunchDisclaimerRepository? localRepository;
  final DisclaimerAcceptanceRepository? acceptanceRepository;

  /// What to show once accepted. Defaults to the game.
  final Widget? child;

  @override
  State<DisclaimerGate> createState() => _DisclaimerGateState();
}

class _DisclaimerGateState extends State<DisclaimerGate> {
  late final DisclaimerGateController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DisclaimerGateController(
      authRepository: widget.authRepository ?? FirebaseAuthRepository(),
      localRepository:
          widget.localRepository ?? LocalFirstLaunchDisclaimerRepository(),
      acceptanceRepository:
          widget.acceptanceRepository ??
          FirestoreDisclaimerAcceptanceRepository(),
      appVersion: '$kAppVersion+$kAppBuildNumber',
    );
    _resolve();
  }

  Future<void> _resolve() async {
    await _controller.resolve();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _accept() async {
    final accepted = await _controller.accept();
    if (!mounted) return;
    setState(() {});
    if (!accepted && _controller.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_controller.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_controller.status) {
      case DisclaimerGateStatus.checking:
        return const _GateBackdrop(child: _GateSpinner());
      case DisclaimerGateStatus.needsAcceptance:
        // The game's own backdrop, so the notice reads as part of the app
        // rather than as a system alert on a blank screen. It is only a
        // picture — the game itself is still not mounted.
        return _GateBackdrop(
          child: FirstLaunchDisclaimerDialog(onOkay: _accept),
        );
      case DisclaimerGateStatus.accepted:
        return widget.child ?? const GameScreen();
    }
  }
}

class _GateBackdrop extends StatelessWidget {
  const _GateBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Same colour the artwork sits on, so a slow decode or a missing
        // asset never shows through as white.
        const ColoredBox(color: Color(0xFF18101F)),
        Image(
          image: GameBackgroundImageProvider.resolve(
            context,
            isFreeSpin: false,
          ),
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.4),
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
        child,
      ],
    );
  }
}

/// Shown for the moment the records are read. The game must not appear before
/// the answer is known, not even for a frame.
class _GateSpinner extends StatelessWidget {
  const _GateSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE5A800)),
        ),
      ),
    );
  }
}
