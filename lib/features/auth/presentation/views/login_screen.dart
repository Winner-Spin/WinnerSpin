import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/typography/app_fonts.dart';

import '../viewmodels/login_viewmodel.dart';
import '../../../../core/widgets/animated_image_button.dart';
import '../models/auth_image_assets.dart';
import '../widgets/account_deleted_dialog.dart';
import '../widgets/auth_field_scroll_coordinator.dart';
import '../widgets/manual_keyboard_scroll_physics.dart';
import 'email_verification_screen.dart';
import 'forgot_password_dialog.dart';
import 'post_login_gate.dart';
import 'register_screen.dart';
import '../../domain/repositories/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.viewModel,
    this.authRepository,
    this.showAccountDeletedNotice = false,
  });

  final LoginViewModel? viewModel;
  final AuthRepository? authRepository;
  final bool showAccountDeletedNotice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundAsset = 'lib/images/login_screen/background_1.png';

  /// Fields are placed as a fraction of the screen height.
  static const double _emailFieldTopFactor = 0.48;
  static const double _passwordFieldTopFactor = 0.58;
  static const double _fieldHeight = 60;

  late final LoginViewModel _viewModel;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final AuthFieldScrollCoordinator _scrollCoordinator =
      AuthFieldScrollCoordinator();
  final GlobalKey _emailFieldKey = GlobalKey();
  final GlobalKey _passwordFieldKey = GlobalKey();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;
  bool _isRoutingToVerification = false;
  bool _accountDeletedNoticeHandled = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.viewModel ??
        (widget.authRepository == null
            ? LoginViewModel()
            : LoginViewModel.withRepository(widget.authRepository!));
    _errorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _errorPulseScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _errorPulseCtrl, curve: Curves.easeOutBack),
    );
    // Initialize every field read by the listener before a method that may
    // synchronously notify it. With music disabled, initMusic reaches
    // notifyListeners without awaiting the audio service.
    _viewModel.addListener(_onViewModelChange);
    unawaited(_viewModel.initMusic());
    _scheduleAccountDeletedNotice();
  }

  void _scheduleAccountDeletedNotice() {
    if (!widget.showAccountDeletedNotice || _accountDeletedNoticeHandled) {
      return;
    }
    _accountDeletedNoticeHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const AccountDeletedDialog(),
        ),
      );
    });
  }

  void _onViewModelChange() {
    _showErrorIfNeeded(context);
    _handleVerificationRequired(context);
    _handleLoginSuccess(context);
    final showsErrorImage =
        _viewModel.errorMessage != null &&
        _viewModel.errorPresentation == LoginErrorPresentation.image;
    if (showsErrorImage && _errorPulseCtrl.value == 0) {
      _errorPulseCtrl.forward(from: 0);
    } else if (!showsErrorImage && _errorPulseCtrl.value != 0) {
      _errorPulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    _errorPulseCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _scrollCoordinator.dispose();
    _viewModel.removeListener(_onViewModelChange);
    unawaited(const AssetImage(_backgroundAsset).evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read this above Scaffold. Scaffold removes the bottom view inset from
    // the MediaQuery exposed to its resized body.
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenH = constraints.maxHeight + keyboardInset;
              final double screenW = constraints.maxWidth;

              return GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: () => FocusScope.of(context).unfocus(),
                child: RawScrollbar(
                  key: const ValueKey('login-screen-scrollbar'),
                  controller: _scrollCoordinator.controller,
                  thumbVisibility: keyboardInset > 0,
                  trackVisibility: false,
                  interactive: true,
                  scrollbarOrientation: ScrollbarOrientation.right,
                  thickness: 4,
                  radius: const Radius.circular(2),
                  thumbColor: const Color(0xCC9E9E9E),
                  mainAxisMargin: 40,
                  crossAxisMargin: 6,
                  child: SingleChildScrollView(
                    key: const ValueKey('login-screen-scroll'),
                    controller: _scrollCoordinator.controller,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    physics: const ManualKeyboardScrollPhysics(),
                    child: SizedBox(
                      key: const ValueKey('login-screen-canvas'),
                      width: screenW,
                      height: screenH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              _backgroundAsset,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                            ),
                          ),

                          Positioned(
                            top: screenH * 0.125,
                            right: screenW * 0.07,
                            child: AnimatedImageButton(
                              imagePath: AuthImageAssets.musicButton,
                              width: 46,
                              isStrikeThrough: _viewModel.isMusicMuted,
                              onTap: () {
                                _viewModel.toggleMusic();
                              },
                            ),
                          ),

                          Positioned(
                            top: screenH * _emailFieldTopFactor,
                            left: screenW * 0.15,
                            right: screenW * 0.15,
                            child: _buildCustomTextField(
                              fieldKey: _emailFieldKey,
                              context: context,
                              controller: _viewModel.emailController,
                              focusNode: _emailFocus,
                              icon: Icons.email,
                              hint: 'Email',
                              backgroundImage: AuthImageAssets.emailField,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onTap: () => _scrollCoordinator.centerField(
                                _emailFieldKey,
                              ),
                              onSubmitted: (_) {
                                _passwordFocus.requestFocus();
                                _scrollCoordinator.centerField(
                                  _passwordFieldKey,
                                );
                              },
                            ),
                          ),

                          Positioned(
                            top: screenH * _passwordFieldTopFactor,
                            left: screenW * 0.15,
                            right: screenW * 0.15,
                            child: _buildCustomTextField(
                              fieldKey: _passwordFieldKey,
                              context: context,
                              controller: _viewModel.passwordController,
                              focusNode: _passwordFocus,
                              icon: Icons.lock,
                              hint: 'Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.done,
                              onTap: () => _scrollCoordinator.centerField(
                                _passwordFieldKey,
                              ),
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                _viewModel.login();
                              },
                            ),
                          ),

                          Positioned(
                            top: screenH * 0.655,
                            left: screenW * 0.15,
                            right: screenW * 0.15,
                            child: Center(
                              child: _buildForgotPasswordLink(context),
                            ),
                          ),

                          Positioned(
                            top: screenH * 0.70,
                            left: screenW * 0.25,
                            right: screenW * 0.25,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: _viewModel.isLoading ? 0.7 : 1.0,
                                    child: AbsorbPointer(
                                      absorbing: _viewModel.isLoading,
                                      child: AnimatedImageButton(
                                        imagePath:
                                            'lib/images/login_screen/login_button_final.png',
                                        width: 180,
                                        onTap: () {
                                          _viewModel.login();
                                        },
                                      ),
                                    ),
                                  ),
                                  if (_viewModel.isLoading)
                                    const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          Positioned(
                            bottom: screenH * 0.165,
                            left: screenW * 0.10,
                            right: screenW * 0.10,
                            child: Center(
                              child: AnimatedImageButton(
                                imagePath:
                                    'lib/images/login_screen/signup_button_final.png',
                                width: 250,
                                onTap: () => _navigateToSignUp(context),
                              ),
                            ),
                          ),

                          if (_viewModel.errorMessage != null &&
                              _viewModel.errorPresentation ==
                                  LoginErrorPresentation.image)
                            Positioned(
                              top: screenH * 0.62,
                              left: screenW * 0.18,
                              right: screenW * 0.18,
                              child: IgnorePointer(
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _errorPulseScale,
                                    child: Image.asset(
                                      'lib/images/login_screen/invalid_error.png',
                                      fit: BoxFit.contain,
                                      filterQuality: FilterQuality.high,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildForgotPasswordLink(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('forgot-password-link'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => _openForgotPassword(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            'FORGOT PASSWORD?',
            textAlign: TextAlign.center,
            style: AppFonts.barlowCondensed(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.6,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openForgotPassword(BuildContext context) {
    // Any message left from a previous attempt would otherwise greet the
    // player before they have asked for anything.
    _viewModel.clearPasswordResetMessage();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ForgotPasswordDialog(
        viewModel: _viewModel,
        initialEmail: _viewModel.emailController.text,
      ),
    );
  }

  void _handleLoginSuccess(BuildContext context) {
    if (!mounted) return;
    if (_viewModel.loginSuccess) {
      _viewModel.resetLoginSuccess();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PostLoginGate(authRepository: widget.authRepository),
        ),
      );
    }
  }

  void _handleVerificationRequired(BuildContext context) {
    if (!mounted ||
        !_viewModel.verificationRequired ||
        _isRoutingToVerification) {
      return;
    }
    final email = _viewModel.verificationEmail;
    if (email == null || email.isEmpty) return;

    _isRoutingToVerification = true;
    _viewModel.resetVerificationRequired();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    });
  }

  Future<void> _navigateToSignUp(BuildContext context) async {
    final navigator = Navigator.of(context);

    await navigator.push(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );

    await _viewModel.onReturned();
  }

  String? _lastShownError;
  Timer? _errorClearTimer;

  void _showErrorIfNeeded(BuildContext context) {
    if (!mounted) return;
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      if (_viewModel.errorPresentation == LoginErrorPresentation.snackBar) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(error),
              duration: const Duration(seconds: 3),
            ),
          );
      }
      _errorClearTimer?.cancel();
      _errorClearTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _viewModel.clearError();
        _lastShownError = null;
      });
    }
  }

  Widget _buildCustomTextField({
    required GlobalKey fieldKey,
    required BuildContext context,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String backgroundImage,
    FocusNode? focusNode,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    VoidCallback? onTap,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      key: fieldKey,
      height: _fieldHeight,
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(backgroundImage),
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 64),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: obscureText,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onTap: onTap,
              onSubmitted: onSubmitted,
              style: AppFonts.nunito(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppFonts.nunito(
                  color: const Color(0xFFFFF0C2).withValues(alpha: 0.74),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: const [
                    Shadow(
                      color: Color(0x99000000),
                      offset: Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
