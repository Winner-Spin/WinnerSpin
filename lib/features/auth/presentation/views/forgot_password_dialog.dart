import 'package:flutter/material.dart';

import '../../../../core/typography/app_fonts.dart';
import '../viewmodels/login_viewmodel.dart';

/// Asks for the account's email and sends a reset link.
///
/// Kept as its own sheet rather than reusing the login fields: the player who
/// needs this is usually the one who just failed to sign in, and reusing those
/// fields would leave a wrong password sitting there.
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({
    super.key,
    required this.viewModel,
    this.initialEmail = '',
  });

  final LoginViewModel viewModel;
  final String initialEmail;

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);

  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final sent = await widget.viewModel.sendPasswordReset(_email.text);
    // The panel stays open on success too: the message explains that the next
    // step happens in the mailbox, which a closing dialog would hide.
    if (sent && mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final message = widget.viewModel.passwordResetMessage;
        final isSending = widget.viewModel.isSendingPasswordReset;

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: _panelColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Enter the email address of your account and we will '
                        'send you a link to set a new password.',
                        textAlign: TextAlign.center,
                        style: AppFonts.barlowCondensed(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _textColor.withValues(alpha: 0.82),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildField(isSending),
                      if (message != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          message,
                          key: const ValueKey('forgot-password-message'),
                          textAlign: TextAlign.center,
                          style: AppFonts.barlowCondensed(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: widget.viewModel.passwordResetFailed
                                ? const Color(0xFFB3261E)
                                : const Color(0xFF1B7A3D),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      _buildActions(isSending),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: _headerColor,
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Center(
        child: Text(
          'RESET PASSWORD',
          style: AppFonts.barlowCondensed(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _buildField(bool isSending) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _textColor.withValues(alpha: 0.18)),
      ),
      child: TextField(
        key: const ValueKey('forgot-password-email'),
        controller: _email,
        enabled: !isSending,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _send(),
        onChanged: (_) => widget.viewModel.clearPasswordResetMessage(),
        style: AppFonts.barlowCondensed(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          prefixIcon: const Icon(Icons.email, size: 18, color: _textColor),
          hintText: 'Email',
          hintStyle: AppFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(bool isSending) {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: isSending ? null : () => Navigator.of(context).pop(),
            child: Text(
              'CLOSE',
              style: AppFonts.barlowCondensed(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton(
            key: const ValueKey('forgot-password-send'),
            onPressed: isSending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF00C76A),
              disabledBackgroundColor: const Color(0xFF9AA39D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'SEND LINK',
                    style: AppFonts.barlowCondensed(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.6,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
