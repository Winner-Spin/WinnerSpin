import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/audio/ambient_music_service.dart';
import '../core/network/internet_connection_monitor.dart';
import '../core/update/app_build_info.dart';
import '../core/update/firestore_required_version_source.dart';
import '../core/update/app_update_monitor.dart';
import '../core/widgets/internet_required_guard.dart';
import '../core/widgets/update_required_guard.dart';
import '../features/auth/data/repositories/firebase_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/login_viewmodel.dart';
import '../features/auth/presentation/views/email_verification_screen.dart';
import '../features/auth/presentation/views/login_screen.dart';
import '../features/slot/presentation/views/game/disclaimer_gate.dart';

/// Root application widget.
class WinnerSpinApp extends StatefulWidget {
  const WinnerSpinApp({
    super.key,
    this.authRepository,
    this.ambientMusicLifecycle,
    this.internetConnectionMonitor,
    this.appUpdateMonitor,
  });

  static const appStoreId = '6795310235';
  static const appStoreUrl = 'https://apps.apple.com/app/id$appStoreId';
  static const playStorePackageName = 'com.winnerspin.game';
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=$playStorePackageName';

  final AuthRepository? authRepository;
  final AmbientMusicLifecycle? ambientMusicLifecycle;
  final InternetConnectionMonitor? internetConnectionMonitor;
  final AppUpdateMonitor? appUpdateMonitor;

  @override
  State<WinnerSpinApp> createState() => _WinnerSpinAppState();
}

class _WinnerSpinAppState extends State<WinnerSpinApp>
    with WidgetsBindingObserver {
  late final AmbientMusicLifecycle _ambientMusicLifecycle;
  late final InternetConnectionMonitor _internetConnectionMonitor;
  late final AppUpdateMonitor _appUpdateMonitor;
  late final bool _ownsInternetConnectionMonitor;
  late final bool _ownsAppUpdateMonitor;
  bool? _isForeground;

  @override
  void initState() {
    super.initState();
    _ambientMusicLifecycle =
        widget.ambientMusicLifecycle ?? AmbientMusicService.instance;
    _ownsInternetConnectionMonitor = widget.internetConnectionMonitor == null;
    _internetConnectionMonitor =
        widget.internetConnectionMonitor ?? AppInternetConnectionMonitor();
    _ownsAppUpdateMonitor = widget.appUpdateMonitor == null;
    _appUpdateMonitor = widget.appUpdateMonitor ?? _createAppUpdateMonitor();
    unawaited(_appUpdateMonitor.refresh());
    unawaited(
      _internetConnectionMonitor.start().then(
        (_) => _internetConnectionMonitor.refresh(),
      ),
    );
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _isForeground = lifecycleState == null
        ? null
        : lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    if (_isForeground == false) {
      unawaited(_ambientMusicLifecycle.pauseForLifecycle());
      unawaited(_internetConnectionMonitor.pause());
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
    if (isForeground) {
      // Re-checked on resume so the block clears right after the user returns
      // from the App Store, without needing a cold start.
      unawaited(_appUpdateMonitor.refresh());
      unawaited(
        _internetConnectionMonitor.start().then(
          (_) => _internetConnectionMonitor.refresh(),
        ),
      );
    } else {
      unawaited(_internetConnectionMonitor.pause());
    }
  }

  AppUpdateMonitor _createAppUpdateMonitor() {
    return StoreAppUpdateMonitor(
      source: FirestoreRequiredVersionSource(platform: defaultTargetPlatform),
      installedVersion: () async => kAppVersion,
      fallbackStoreUrl: switch (defaultTargetPlatform) {
        TargetPlatform.android => WinnerSpinApp.playStoreUrl,
        TargetPlatform.iOS || TargetPlatform.macOS => WinnerSpinApp.appStoreUrl,
        _ => null,
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsInternetConnectionMonitor) {
      _internetConnectionMonitor.dispose();
    }
    if (_ownsAppUpdateMonitor) {
      _appUpdateMonitor.dispose();
    }
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
      // Offline wins over the update prompt: with no connection the update
      // check cannot conclude anything, so the connection warning is the
      // actionable one.
      builder: (context, child) => InternetRequiredGuard(
        monitor: _internetConnectionMonitor,
        child: UpdateRequiredGuard(
          monitor: _appUpdateMonitor,
          child: child ?? const SizedBox.shrink(),
        ),
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
    if (_authRepository.currentUserEmailVerified) return const DisclaimerGate();

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
