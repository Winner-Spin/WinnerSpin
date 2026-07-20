import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../slot/presentation/views/game/game_screen.dart';
import '../../../slot/presentation/views/shared/widgets/spring_popup_card.dart';
import '../../domain/repositories/auth_repository.dart';
import '../viewmodels/email_verification_viewmodel.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    this.viewModel,
    this.authRepository,
    this.sendLinkOnOpen = true,
    this.onVerified,
    this.onCancel,
  });

  final String email;
  final EmailVerificationViewModel? viewModel;
  final AuthRepository? authRepository;
  final bool sendLinkOnOpen;
  final VoidCallback? onVerified;
  final VoidCallback? onCancel;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _goldColor = Color(0xFFE5A800);

  late final EmailVerificationViewModel _viewModel;
  late final bool _ownsViewModel;
  bool _handledSuccess = false;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsViewModel = widget.viewModel == null;
    _viewModel =
        widget.viewModel ??
        EmailVerificationViewModel(
          email: widget.email,
          authRepository: widget.authRepository,
        );
    _viewModel.addListener(_onViewModelChanged);
    if (widget.sendLinkOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_viewModel.sendVerificationLink());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChanged);
    if (_ownsViewModel) _viewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_viewModel.checkVerificationStatus(silent: true));
    }
  }

  void _onViewModelChanged() {
    if (!_viewModel.verificationSuccess || _handledSuccess) return;
    _handledSuccess = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final callback = widget.onVerified;
      if (callback != null) {
        callback();
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GameScreen()),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/images/login_screen/background_1.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.48)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 24,
                ),
                child: SpringPopupCard(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _panelColor,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.36),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: AnimatedBuilder(
                        animation: _viewModel,
                        builder: (context, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                26,
                                24,
                                26,
                              ),
                              child: _buildContent(),
                            ),
                          ],
                        ),
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

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        color: _headerColor,
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'VERIFY EMAIL',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _isCancelling ? null : _cancel,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: _isCancelling
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _textColor,
                        ),
                      )
                    : const Icon(Icons.close, size: 30, color: _textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _panelAccent,
              shape: BoxShape.circle,
              border: Border.all(color: _goldColor, width: 3),
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              size: 44,
              color: _textColor,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'CHECK YOUR EMAIL',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'We sent a verification link to',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textColor.withValues(alpha: 0.64),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          widget.email,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _textColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link_rounded, color: _goldColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open the email and tap VERIFY EMAIL. Then return to Winner Spin.',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_viewModel.message != null) ...[
          const SizedBox(height: 13),
          Text(
            _viewModel.message!,
            textAlign: TextAlign.center,
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _viewModel.messageIsError
                  ? const Color(0xFFB3261E)
                  : const Color(0xFF247A3D),
            ),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('verify-email-button'),
          onPressed: _viewModel.isChecking
              ? null
              : _viewModel.checkVerificationStatus,
          style: FilledButton.styleFrom(
            backgroundColor: _textColor,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _textColor.withValues(alpha: 0.42),
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          icon: _viewModel.isChecking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.verified_rounded),
          label: Text(
            _viewModel.isChecking ? 'CHECKING...' : "I'VE VERIFIED MY EMAIL",
            style: GoogleFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          key: const ValueKey('resend-email-button'),
          onPressed: _viewModel.canResend
              ? _viewModel.sendVerificationLink
              : null,
          child: Text(
            _viewModel.resendSecondsRemaining > 0
                ? 'RESEND EMAIL (${_viewModel.resendSecondsRemaining}s)'
                : 'RESEND EMAIL',
            style: GoogleFonts.barlowCondensed(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: _viewModel.canResend
                  ? _textColor
                  : _textColor.withValues(alpha: 0.40),
            ),
          ),
        ),
        TextButton(
          onPressed: _isCancelling ? null : _cancel,
          child: Text(
            'USE A DIFFERENT ACCOUNT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textColor.withValues(alpha: 0.64),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _cancel() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    await _viewModel.cancelVerification();
    if (!mounted) return;

    final callback = widget.onCancel;
    if (callback != null) {
      callback();
      return;
    }
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }
}
