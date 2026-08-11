import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/typography/app_fonts.dart';
import '../../../slot/data/repositories/local_user_data_eraser.dart';
import '../../../slot/presentation/views/game/disclaimer_gate.dart';
import '../../../slot/presentation/views/shared/widgets/spring_popup_card.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../viewmodels/login_viewmodel.dart';
import 'login_screen.dart';

/// Prevents a verified auth account with a missing profile from entering game.
class PostLoginGate extends StatefulWidget {
  const PostLoginGate({
    super.key,
    this.authRepository,
    this.localUserDataEraser = const LocalUserDataEraser(),
    this.presentDestinationBuilder,
  });

  final AuthRepository? authRepository;
  final LocalUserDataEraser localUserDataEraser;
  final Widget Function(AuthRepository authRepository)?
  presentDestinationBuilder;

  @override
  State<PostLoginGate> createState() => _PostLoginGateState();
}

class _PostLoginGateState extends State<PostLoginGate> {
  late final AuthRepository _authRepository;
  late Future<UserProfileExistence> _profileExistence;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? FirebaseAuthRepository();
    _profileExistence = _lookupProfile();
  }

  Future<UserProfileExistence> _lookupProfile() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) return UserProfileExistence.missing;
    return await _authRepository.getUserProfileExistence(userId);
  }

  void _retry() {
    final profileExistence = Completer<UserProfileExistence>();
    setState(() {
      _profileExistence = profileExistence.future;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        profileExistence.complete(await _lookupProfile());
      } catch (error, stackTrace) {
        profileExistence.completeError(error, stackTrace);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfileExistence>(
      future: _profileExistence,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ProfileGateLoading();
        }
        if (snapshot.hasError) {
          return _ProfileLookupErrorScreen(
            authRepository: _authRepository,
            onRetry: _retry,
          );
        }
        if (snapshot.data == UserProfileExistence.present) {
          final destinationBuilder = widget.presentDestinationBuilder;
          if (destinationBuilder != null) {
            return destinationBuilder(_authRepository);
          }
          return DisclaimerGate(authRepository: _authRepository);
        }
        return MissingProfileRecoveryScreen(
          authRepository: _authRepository,
          localUserDataEraser: widget.localUserDataEraser,
        );
      },
    );
  }
}

class _ProfileGateLoading extends StatelessWidget {
  const _ProfileGateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF18101F),
      body: Center(child: CircularProgressIndicator(color: Color(0xFFE5A800))),
    );
  }
}

class _ProfileLookupErrorScreen extends StatelessWidget {
  const _ProfileLookupErrorScreen({
    required this.authRepository,
    required this.onRetry,
  });

  final AuthRepository authRepository;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _RecoveryPanel(
      title: 'PROFILE CHECK FAILED',
      icon: Icons.cloud_off_rounded,
      message:
          'Your profile status could not be checked. Try again before '
          'continuing, or sign out safely.',
      children: [
        FilledButton(
          key: const ValueKey('profile-gate-retry-button'),
          onPressed: onRetry,
          child: const Text('RETRY'),
        ),
        TextButton(
          key: const ValueKey('profile-gate-sign-out-button'),
          onPressed: () => _signOutToLogin(context, authRepository),
          child: const Text('SIGN OUT'),
        ),
      ],
    );
  }
}

class MissingProfileRecoveryScreen extends StatefulWidget {
  const MissingProfileRecoveryScreen({
    super.key,
    required this.authRepository,
    this.localUserDataEraser = const LocalUserDataEraser(),
  });

  final AuthRepository authRepository;
  final LocalUserDataEraser localUserDataEraser;

  @override
  State<MissingProfileRecoveryScreen> createState() =>
      _MissingProfileRecoveryScreenState();
}

class _MissingProfileRecoveryScreenState
    extends State<MissingProfileRecoveryScreen> {
  final TextEditingController _password = TextEditingController();
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() => setState(() {});

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _password.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_isDeleting || _password.text.isEmpty) return;
    final userId = widget.authRepository.currentUserId;
    if (userId == null) {
      await _toLogin(showAccountDeletedNotice: false);
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });
    try {
      await widget.authRepository.deleteAccount(
        _password.text,
        beforeAuthDeletion: widget.localUserDataEraser.eraseFor,
      );
      if (mounted) await _toLogin(showAccountDeletedNotice: true);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = switch (error.code) {
          AuthErrorCode.wrongPassword || AuthErrorCode.invalidCredential =>
            'Incorrect password. The account was not deleted.',
          AuthErrorCode.networkRequestFailed =>
            'Account deletion requires a network connection. Please try again.',
          _ => 'Account could not be deleted. Please try again.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Account could not be deleted. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _toLogin({required bool showAccountDeletedNotice}) async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          authRepository: widget.authRepository,
          viewModel: LoginViewModel.withRepository(widget.authRepository),
          showAccountDeletedNotice: showAccountDeletedNotice,
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RecoveryPanel(
      title: 'ACCOUNT RECOVERY',
      icon: Icons.person_off_rounded,
      message:
          'Your sign-in account exists, but its profile data is missing. '
          'For your security, the game stays locked. Delete the incomplete '
          'account or sign out.',
      children: [
        TextField(
          key: const ValueKey('profile-recovery-password'),
          controller: _password,
          obscureText: true,
          enabled: !_isDeleting,
          decoration: const InputDecoration(
            labelText: 'Password',
            filled: true,
            fillColor: Colors.white70,
            border: OutlineInputBorder(),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFB3261E),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          key: const ValueKey('profile-recovery-delete-button'),
          onPressed: !_isDeleting && _password.text.isNotEmpty
              ? _deleteAccount
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            minimumSize: const Size.fromHeight(52),
          ),
          child: Text(_isDeleting ? 'DELETING...' : 'DELETE THIS ACCOUNT'),
        ),
        TextButton(
          key: const ValueKey('profile-recovery-sign-out-button'),
          onPressed: _isDeleting
              ? null
              : () => _signOutToLogin(context, widget.authRepository),
          child: const Text('SIGN OUT'),
        ),
      ],
    );
  }
}

class _RecoveryPanel extends StatelessWidget {
  const _RecoveryPanel({
    required this.title,
    required this.icon,
    required this.message,
    required this.children,
  });

  final String title;
  final IconData icon;
  final String message;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const panel = Color(0xFFF0CDE6);
    const text = Color(0xFF2C2530);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/images/login_screen/background_1.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.48)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: SpringPopupCard(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(icon, size: 64, color: text),
                          const SizedBox(height: 14),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: AppFonts.barlowCondensed(
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: AppFonts.barlowCondensed(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 22),
                          ...children,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _signOutToLogin(
  BuildContext context,
  AuthRepository authRepository,
) async {
  await authRepository.signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => LoginScreen(
        authRepository: authRepository,
        viewModel: LoginViewModel.withRepository(authRepository),
      ),
    ),
    (_) => false,
  );
}
