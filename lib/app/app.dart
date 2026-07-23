import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio/ambient_music_service.dart';
import '../features/auth/data/repositories/firebase_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/login_viewmodel.dart';
import '../features/auth/presentation/views/email_verification_screen.dart';
import '../features/auth/presentation/views/login_screen.dart';
import '../features/slot/presentation/views/game/game_screen.dart';

/// Root application widget.
class WinnerSpinApp extends StatefulWidget {
  const WinnerSpinApp({
    super.key,
    this.authRepository,
    this.ambientMusicLifecycle,
  });

  final AuthRepository? authRepository;
  final AmbientMusicLifecycle? ambientMusicLifecycle;

  @override
  State<WinnerSpinApp> createState() => _WinnerSpinAppState();
}

class _WinnerSpinAppState extends State<WinnerSpinApp>
    with WidgetsBindingObserver {
  late final AmbientMusicLifecycle _ambientMusicLifecycle;
  bool? _isForeground;

  @override
  void initState() {
    super.initState();
    _ambientMusicLifecycle =
        widget.ambientMusicLifecycle ?? AmbientMusicService.instance;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycleState == null
        ? null
        : lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (_isForeground == false) {
      unawaited(_ambientMusicLifecycle.pauseForLifecycle());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_isForeground == isForeground) return;

    _isForeground = isForeground;
    unawaited(
      isForeground
          ? _ambientMusicLifecycle.resumeAfterLifecycle()
          : _ambientMusicLifecycle.pauseForLifecycle(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Winner Spin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _AuthGate(authRepository: widget.authRepository),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final AuthRepository _authRepository;
  late final Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _authRepository = widget.authRepository ?? FirebaseAuthRepository();
    _destination = _resolveDestination();
  }

  Future<Widget> _resolveDestination() async {
    if (_authRepository.currentUserId == null) return _loginScreen();

    try {
      await _authRepository.reloadCurrentUser();
    } catch (_) {
      // Cached auth state still safely keeps unverified users out of the game.
    }

    if (_authRepository.currentUserId == null) return _loginScreen();
    if (_authRepository.currentUserEmailVerified) return const GameScreen();

    final email = _authRepository.currentUserEmail;
    if (email == null || email.isEmpty) {
      await _authRepository.signOut();
      return _loginScreen();
    }
    return EmailVerificationScreen(
      email: email,
      authRepository: widget.authRepository == null ? null : _authRepository,
    );
  }

  Widget _loginScreen() {
    if (widget.authRepository == null) return const LoginScreen();
    return LoginScreen(
      viewModel: LoginViewModel.withRepository(_authRepository),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.hasData) return snapshot.data!;
        return const Scaffold(
          backgroundColor: Color(0xFF18101F),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFE5A800)),
          ),
        );
      },
    );
  }
}
