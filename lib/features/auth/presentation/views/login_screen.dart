import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/typography/app_fonts.dart';

import '../viewmodels/login_viewmodel.dart';
import '../../../../core/widgets/animated_image_button.dart';
import '../models/auth_image_assets.dart';
import '../widgets/account_deleted_dialog.dart';
import 'email_verification_screen.dart';
import 'forgot_password_dialog.dart';
import 'register_screen.dart';
import '../../../slot/presentation/views/game/disclaimer_gate.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.viewModel,
    this.showAccountDeletedNotice = false,
  });

  final LoginViewModel? viewModel;
  final bool showAccountDeletedNotice;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundAsset = 'lib/images/login_screen/background_1.png';

  /// Fields are placed as a fraction of the screen height, so the same
  /// constants drive both the layout and the keyboard avoidance math.
  static const double _emailFieldTopFactor = 0.48;
  static const double _passwordFieldTopFactor = 0.58;
  static const double _fieldHeight = 60;
  static const double _keyboardGap = 24;

  late final LoginViewModel _viewModel;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;
  bool _isRoutingToVerification = false;
  bool _accountDeletedNoticeHandled = false;

  @override
  void initState() {
    super.initState();
    _viewModel = widget.viewModel ?? LoginViewModel();
    _viewModel.addListener(_onViewModelChange);
    _emailFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    unawaited(_viewModel.initMusic());
    _errorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _errorPulseScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _errorPulseCtrl, curve: Curves.easeOutBack),
    );
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

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// How far the content must slide up so the focused field stays above the
  /// on-screen keyboard.
  double _keyboardShift(double screenH, double bottomInset) {
    if (bottomInset <= 0) return 0;
    final double? topFactor = _passwordFocus.hasFocus
        ? _passwordFieldTopFactor
        : _emailFocus.hasFocus
        ? _emailFieldTopFactor
        : null;
    if (topFactor == null) return 0;
    final double fieldBottom =
        screenH * topFactor + _fieldHeight + _keyboardGap;
    return math.max(0.0, fieldBottom - (screenH - bottomInset));
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    _errorPulseCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _viewModel.removeListener(_onViewModelChange);
    unawaited(const AssetImage(_backgroundAsset).evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenH = constraints.maxHeight;
              final double screenW = constraints.maxWidth;
              final double shift = _keyboardShift(screenH, bottomInset);

              return GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        _backgroundAsset,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                    ),

                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      left: 0,
                      right: 0,
                      top: -shift,
                      height: screenH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
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
                              context: context,
                              controller: _viewModel.emailController,
                              focusNode: _emailFocus,
                              icon: Icons.email,
                              hint: 'Email',
                              backgroundImage: AuthImageAssets.emailField,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passwordFocus.requestFocus(),
                            ),
                          ),

                          Positioned(
                            top: screenH * _passwordFieldTopFactor,
                            left: screenW * 0.15,
                            right: screenW * 0.15,
                            child: _buildCustomTextField(
                              context: context,
                              controller: _viewModel.passwordController,
                              focusNode: _passwordFocus,
                              icon: Icons.lock,
                              hint: 'Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.done,
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
                  ],
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
        MaterialPageRoute(builder: (context) => const DisclaimerGate()),
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
    required BuildContext context,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String backgroundImage,
    FocusNode? focusNode,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
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
