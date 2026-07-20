import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/models/email_verification_failure.dart';
import '../../domain/repositories/auth_repository.dart';

class EmailVerificationViewModel extends ChangeNotifier {
  EmailVerificationViewModel({
    required this.email,
    AuthRepository? authRepository,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository();

  final String email;
  final AuthRepository _authRepository;

  bool _isSendingLink = false;
  bool get isSendingLink => _isSendingLink;

  bool _isChecking = false;
  bool get isChecking => _isChecking;

  bool _verificationSuccess = false;
  bool get verificationSuccess => _verificationSuccess;

  String? _message;
  String? get message => _message;

  bool _messageIsError = false;
  bool get messageIsError => _messageIsError;

  int _resendSecondsRemaining = 0;
  int get resendSecondsRemaining => _resendSecondsRemaining;
  bool get canResend =>
      !_isSendingLink && !_isChecking && _resendSecondsRemaining == 0;

  Timer? _resendTimer;

  Future<void> sendVerificationLink() async {
    if (_isSendingLink || _verificationSuccess) return;
    _isSendingLink = true;
    _setMessage(null);
    notifyListeners();

    try {
      await _authRepository.sendEmailVerificationLink();
      _setMessage(
        'Verification email sent to $email. Open the link, then return here.',
      );
      _startResendCountdown(60);
    } on EmailVerificationException catch (error) {
      _handleVerificationError(error);
    } catch (_) {
      _setMessage(
        'The verification email could not be sent. Please try again.',
        isError: true,
      );
    } finally {
      _isSendingLink = false;
      notifyListeners();
    }
  }

  Future<void> checkVerificationStatus({bool silent = false}) async {
    if (_isChecking || _verificationSuccess) return;
    _isChecking = true;
    if (!silent) _setMessage(null);
    notifyListeners();

    try {
      await _authRepository.reloadCurrentUser();
      if (_authRepository.currentUserEmailVerified) {
        _verificationSuccess = true;
        _setMessage('Email verified successfully. Signing you in...');
      } else if (!silent) {
        _setMessage(
          'Email is not verified yet. Open the link in your email, then try again.',
          isError: true,
        );
      }
    } catch (_) {
      if (!silent) {
        _setMessage(
          'Verification status could not be checked. Please try again.',
          isError: true,
        );
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> cancelVerification() => _authRepository.signOut();

  void _handleVerificationError(EmailVerificationException error) {
    switch (error.code) {
      case EmailVerificationFailureCode.tooManyRequests:
        _startResendCountdown(60);
        _setMessage(
          'Too many verification emails were requested. Please wait and try again.',
          isError: true,
        );
      case EmailVerificationFailureCode.unavailable:
        _setMessage(
          'The verification service is temporarily unavailable.',
          isError: true,
        );
      case EmailVerificationFailureCode.unknown:
        _setMessage('Verification failed. Please try again.', isError: true);
    }
  }

  void _startResendCountdown(int seconds) {
    _resendTimer?.cancel();
    _resendSecondsRemaining = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsRemaining <= 1) {
        timer.cancel();
        _resendSecondsRemaining = 0;
      } else {
        _resendSecondsRemaining--;
      }
      notifyListeners();
    });
  }

  void _setMessage(String? value, {bool isError = false}) {
    _message = value;
    _messageIsError = isError;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }
}
