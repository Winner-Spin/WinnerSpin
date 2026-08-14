import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/typography/app_fonts.dart';

import '../../../../core/widgets/animated_image_button.dart';
import '../models/auth_image_assets.dart';
import '../viewmodels/register_viewmodel.dart';
import '../widgets/auth_field_scroll_coordinator.dart';
import '../widgets/manual_keyboard_scroll_physics.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.viewModel});

  final RegisterViewModel? viewModel;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  static const _backgroundAsset = 'lib/images/register_screen/register.png';

  /// Fields are placed as a fraction of the screen height.
  static const double _nameFieldTopFactor = 0.34;
  static const double _emailFieldTopFactor = 0.43;
  static const double _passwordFieldTopFactor = 0.52;
  static const double _confirmFieldTopFactor = 0.61;
  static const double _fieldHeight = 60;

  late final RegisterViewModel _viewModel;
  late final bool _ownsViewModel;

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  final AuthFieldScrollCoordinator _scrollCoordinator =
      AuthFieldScrollCoordinator();
  final GlobalKey _nameFieldKey = GlobalKey();
  final GlobalKey _emailFieldKey = GlobalKey();
  final GlobalKey _passwordFieldKey = GlobalKey();
  final GlobalKey _confirmFieldKey = GlobalKey();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;
  Timer? _errorClearTimer;
  String? _lastShownError;
  bool _isRoutingToVerification = false;

  @override
  void initState() {
    super.initState();
    _ownsViewModel = widget.viewModel == null;
    _viewModel = widget.viewModel ?? RegisterViewModel();
    _errorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _errorPulseScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _errorPulseCtrl, curve: Curves.easeOutBack),
    );
    _viewModel.addListener(_onViewModelChange);
    unawaited(_viewModel.initMusic());
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

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    _errorPulseCtrl.dispose();
    for (final node in _focusNodes) {
      node.dispose();
    }
    _scrollCoordinator.dispose();
    _viewModel.removeListener(_onViewModelChange);
    if (_ownsViewModel) _viewModel.dispose();
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
                  key: const ValueKey('register-screen-scrollbar'),
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
                    key: const ValueKey('register-screen-scroll'),
                    controller: _scrollCoordinator.controller,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    physics: const ManualKeyboardScrollPhysics(),
                    child: SizedBox(
                      key: const ValueKey('register-screen-canvas'),
                      width: screenW,
                      height: screenH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              _backgroundAsset,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.high,
                            ),
                          ),

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
                              fieldKey: _nameFieldKey,
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
                              onTap: () =>
                                  _scrollCoordinator.centerField(_nameFieldKey),
                              onSubmitted: (_) {
                                _emailFocus.requestFocus();
                                _scrollCoordinator.centerField(_emailFieldKey);
                              },
                            ),
                          ),

                          Positioned(
                            top: screenH * _emailFieldTopFactor,
                            left: screenW * 0.13,
                            right: screenW * 0.13,
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
                            left: screenW * 0.13,
                            right: screenW * 0.13,
                            child: _buildCustomTextField(
                              fieldKey: _passwordFieldKey,
                              context: context,
                              controller: _viewModel.passwordController,
                              focusNode: _passwordFocus,
                              icon: Icons.lock,
                              hint: 'Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.next,
                              onTap: () => _scrollCoordinator.centerField(
                                _passwordFieldKey,
                              ),
                              onSubmitted: (_) {
                                _confirmFocus.requestFocus();
                                _scrollCoordinator.centerField(
                                  _confirmFieldKey,
                                );
                              },
                            ),
                          ),

                          Positioned(
                            top: screenH * _confirmFieldTopFactor,
                            left: screenW * 0.13,
                            right: screenW * 0.13,
                            child: _buildCustomTextField(
                              fieldKey: _confirmFieldKey,
                              context: context,
                              controller: _viewModel.passwordConfirmController,
                              focusNode: _confirmFocus,
                              icon: Icons.lock_outline,
                              hint: 'Confirm Password',
                              obscureText: true,
                              backgroundImage: AuthImageAssets.passwordField,
                              textInputAction: TextInputAction.done,
                              onTap: () => _scrollCoordinator.centerField(
                                _confirmFieldKey,
                              ),
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
                                imagePath:
                                    'lib/images/register_screen/image.png',
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
                  ),
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
    required GlobalKey fieldKey,
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
    VoidCallback? onTap,
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
        key: fieldKey,
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
      key: fieldKey,
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
