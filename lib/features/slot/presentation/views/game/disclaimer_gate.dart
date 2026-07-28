import 'package:flutter/material.dart';

import '../../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../../../core/update/app_build_info.dart';
import '../../../data/repositories/firestore_disclaimer_acceptance_repository.dart';
import '../../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../../services/game_background_image_provider.dart';
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

enum _GateStatus { checking, needsAcceptance, accepted }

class _DisclaimerGateState extends State<DisclaimerGate> {
  late final AuthRepository _authRepository;
  late final FirstLaunchDisclaimerRepository _local;
  late final DisclaimerAcceptanceRepository _acceptance;

  _GateStatus _status = _GateStatus.checking;
  bool _isRecording = false;

  String? get _userId => _authRepository.currentUserId;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? FirebaseAuthRepository();
    _local = widget.localRepository ?? LocalFirstLaunchDisclaimerRepository();
    _acceptance =
        widget.acceptanceRepository ??
        FirestoreDisclaimerAcceptanceRepository();
    _resolve();
  }

  Future<void> _resolve() async {
    final status = await _resolveStatus();
    if (!mounted) return;
    setState(() => _status = status);
  }

  /// The device answer is authoritative when it exists; the account is only
  /// consulted when this device has no record, which is the reinstall and
  /// second-device case.
  ///
  /// Every failure lands on [_GateStatus.needsAcceptance]. Asking a second time
  /// costs a tap; letting someone through unasked costs the record entirely.
  Future<_GateStatus> _resolveStatus() async {
    final userId = _userId;
    if (userId == null) return _GateStatus.needsAcceptance;

    try {
      if (await _local.hasSeenDisclaimer(userId)) return _GateStatus.accepted;
    } catch (_) {
      // Fall through to the remote check.
    }

    try {
      final accepted = await _acceptance.hasAccepted(
        userId: userId,
        version: kDisclaimerVersion,
      );
      if (!accepted) return _GateStatus.needsAcceptance;
      // Mirror it so the next launch answers without a network read.
      await _markSeenQuietly(userId);
      return _GateStatus.accepted;
    } catch (_) {
      return _GateStatus.needsAcceptance;
    }
  }

  Future<void> _accept() async {
    if (_isRecording) return;
    _isRecording = true;

    final userId = _userId;
    if (userId != null) {
      // The device record is written first: it is what stops the notice coming
      // back on every launch, and it must not depend on the network.
      await _markSeenQuietly(userId);
      try {
        await _acceptance.recordAcceptance(
          userId: userId,
          version: kDisclaimerVersion,
          appVersion: '$kAppVersion+$kAppBuildNumber',
        );
      } catch (_) {
        // Losing the evidence copy must not lock the player out of the game.
      }
    }

    if (!mounted) return;
    setState(() => _status = _GateStatus.accepted);
  }

  Future<void> _markSeenQuietly(String userId) async {
    try {
      await _local.markDisclaimerSeen(userId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _GateStatus.checking:
        return const _GateBackdrop(child: _GateSpinner());
      case _GateStatus.needsAcceptance:
        // The game's own backdrop, so the notice reads as part of the app
        // rather than as a system alert on a blank screen. It is only a
        // picture — the game itself is still not mounted.
        return _GateBackdrop(
          child: FirstLaunchDisclaimerDialog(onOkay: _accept),
        );
      case _GateStatus.accepted:
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
