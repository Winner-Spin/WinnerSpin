import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../core/typography/app_fonts.dart';

import '../../../../core/widgets/animated_image_button.dart';
import '../models/auth_image_assets.dart';
import '../viewmodels/register_viewmodel.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundAsset = 'lib/images/register_screen/register.png';

  /// Fields are placed as a fraction of the screen height, so the same
  /// constants drive both the layout and the keyboard avoidance math.
  static const double _nameFieldTopFactor = 0.34;
  static const double _emailFieldTopFactor = 0.43;
  static const double _passwordFieldTopFactor = 0.52;
  static const double _confirmFieldTopFactor = 0.61;
  static const double _fieldHeight = 60;
  static const double _keyboardGap = 24;

  final RegisterViewModel _viewModel = RegisterViewModel();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;
  Timer? _errorClearTimer;
  String? _lastShownError;
  bool _isRoutingToVerification = false;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    for (final node in _focusNodes) {
      node.addListener(_onFocusChange);
    }
    unawaited(_viewModel.initMusic());
    _errorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _errorPulseScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _errorPulseCtrl, curve: Curves.easeOutBack),
    );
  }

  void _onViewModelChange() {
    _showErrorIfNeeded(context);
    _handleRegistrationSuccess(context);
    final hasError = _viewModel.errorMessage != null;
    if (hasError && _errorPulseCtrl.value == 0) {
      _errorPulseCtrl.forward(from: 0);
    } else if (!hasError && _errorPulseCtrl.value != 0) {
      _errorPulseCtrl.value = 0;
    }
  }

  List<FocusNode> get _focusNodes => [
    _nameFocus,
    _emailFocus,
    _passwordFocus,
    _confirmFocus,
  ];

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  /// How far the content must slide up so the focused field stays above the
  /// on-screen keyboard.
  double _keyboardShift(double screenH, double bottomInset) {
    if (bottomInset <= 0) return 0;
    double? topFactor;
    if (_confirmFocus.hasFocus) {
      topFactor = _confirmFieldTopFactor;
    } else if (_passwordFocus.hasFocus) {
      topFactor = _passwordFieldTopFactor;
    } else if (_emailFocus.hasFocus) {
      topFactor = _emailFieldTopFactor;
    } else if (_nameFocus.hasFocus) {
      topFactor = _nameFieldTopFactor;
    }
    if (topFactor == null) return 0;
    final double fieldBottom =
        screenH * topFactor + _fieldHeight + _keyboardGap;
    return math.max(0.0, fieldBottom - (screenH - bottomInset));
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    _errorPulseCtrl.dispose();
    for (final node in _focusNodes) {
      node.dispose();
    }
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.dispose();
    unawaited(const AssetImage(_backgroundAsset).evict());
    super.dispose();
  }

  String? _errorImageFor(String error) {
    if (error.contains('fill in all fields')) {
      return 'lib/images/register_screen/empty_fields.png';
    }
    if (error.contains('do not match')) {
      return 'lib/images/register_screen/password_dont_match.png';
    }
    if (error.contains('at least 6 characters') || error.contains('too weak')) {
      return 'lib/images/register_screen/min_6_characters.png';
    }
    if (error.contains('Invalid email')) {
      return 'lib/images/register_screen/invalid_email_adress.png';
    }
    return null;
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
                        fit: BoxFit.fill,
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
                            top: screenH * 0.07,
                            right: screenW * 0.07,
                            child: AnimatedImageButton(
                              imagePath: AuthImageAssets.musicButton,
                              width: 46,
                              isStrikeThrough: _viewModel.isMusicMuted,
                              onTap: _viewModel.toggleMusic,
                            ),
                          ),

                          Positioned(
                            top: screenH * _nameFieldTopFactor,
                            left: screenW * 0.13,
                            right: screenW * 0.13,
                            child: _buildCustomTextField(
                              context: context,
                              controller: _viewModel.nameController,
                              focusNode: _nameFocus,
                              icon: Icons.star,
                              hint: 'Username',
                              backgroundImage:
                                  'lib/images/register_screen/Ad_Soyad_button.png',
                              leadingSpace: 64,
                              contentPadding: const EdgeInsets.only(top: 4),
                              backgroundScaleY: 1.58,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _emailFocus.requestFocus(),
                            ),
                          ),

                          Positioned(
                            top: screenH * _emailFieldTopFactor,
                            left: screenW * 0.13,
                            right: screenW * 0.13,
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
                            left: screenW * 0.13,
                            right: screenW * 0.13,
                            child: _buildCustomTextField(
                              context: context,
                              controller: _viewModel.passwordController,
                              focusNode: _passwordFocus,
                              icon: Icons.lock,
                              hint: 'Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _confirmFocus.requestFocus(),
                            ),
                          ),

                          Positioned(
                            top: screenH * _confirmFieldTopFactor,
                            left: screenW * 0.13,
                            right: screenW * 0.13,
                            child: _buildCustomTextField(
                              context: context,
                              controller: _viewModel.passwordConfirmController,
                              focusNode: _confirmFocus,
                              icon: Icons.lock_outline,
                              hint: 'Confirm Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) {
                                FocusScope.of(context).unfocus();
                                _viewModel.register();
                              },
                            ),
                          ),

                          Positioned(
                            bottom: screenH * 0.14,
                            left: screenW * 0.15,
                            right: screenW * 0.15,
                            child: Center(
                              child: AnimatedImageButton(
                                imagePath: 'lib/images/register_screen/image.png',
                                width: 540,
                                height: 90,
                                onTap: () => Navigator.pop(context),
                              ),
                            ),
                          ),

                          Positioned(
                            top: screenH * 0.695,
                            left: screenW * 0.21,
                            right: screenW * 0.21,
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Opacity(
                                    opacity: _viewModel.isLoading ? 0.7 : 1.0,
                                    child: AbsorbPointer(
                                      absorbing: _viewModel.isLoading,
                                      child: _buildKayitButton(
                                        onTap: () {
                                          _viewModel.register();
                                        },
                                      ),
                                    ),
                                  ),
                                  if (_viewModel.isLoading)
                                    const SizedBox(
                                      width: 28,
                                      height: 27,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          if (_viewModel.errorMessage != null &&
                              _errorImageFor(_viewModel.errorMessage!) != null)
                            Positioned(
                              bottom: screenH * 0.27,
                              left: screenW * 0.18,
                              right: screenW * 0.18,
                              child: IgnorePointer(
                                child: Center(
                                  child: ScaleTransition(
                                    scale: _errorPulseScale,
                                    child: Image.asset(
                                      _errorImageFor(_viewModel.errorMessage!)!,
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

  void _handleRegistrationSuccess(BuildContext context) {
    if (!mounted) return;
    if (!_viewModel.registrationSuccess || _isRoutingToVerification) return;
    final email = _viewModel.verificationEmail;
    if (email == null || email.isEmpty) return;

    _isRoutingToVerification = true;
    _viewModel.resetRegistrationSuccess();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    });
  }

  void _showErrorIfNeeded(BuildContext context) {
    if (!mounted) return;
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      if (_errorImageFor(error) == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
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
    double leadingSpace = 64,
    EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
    double backgroundScaleY = 1,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    final fieldContent = Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: leadingSpace),
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
                contentPadding: contentPadding,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );

    if (backgroundScaleY == 1) {
      return Container(
        height: _fieldHeight,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.fill,
          ),
        ),
        child: fieldContent,
      );
    }

    return SizedBox(
      height: _fieldHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.scale(
                scaleY: backgroundScaleY,
                child: Image.asset(
                  backgroundImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned.fill(child: fieldContent),
          ],
        ),
      ),
    );
  }

  Widget _buildKayitButton({required VoidCallback onTap}) {
    return AnimatedImageButton(
      imagePath: 'lib/images/register_screen/register_button_clean.png',
      width: 235,
      onTap: onTap,
    );
  }
}
