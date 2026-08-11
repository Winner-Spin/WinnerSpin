import 'package:flutter/material.dart';

import '../../../../core/typography/app_fonts.dart';

/// Confirms account deletion and collects the password in one step.
class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({
    super.key,
    this.description =
        'This permanently deletes your account and game data. '
        'This action cannot be undone. Enter your password to confirm.',
  });

  final String description;

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);

  final TextEditingController _password = TextEditingController();
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    final canDelete = _password.text.isNotEmpty;
    if (canDelete != _canDelete) setState(() => _canDelete = canDelete);
  }

  @override
  void dispose() {
    _password.removeListener(_onPasswordChanged);
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      backgroundColor: _headerColor,
      title: Text(
        'DELETE ACCOUNT?',
        style: AppFonts.barlowCondensed(
          fontWeight: FontWeight.w900,
          color: _textColor,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.description,
            style: AppFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('delete-account-password'),
            controller: _password,
            obscureText: true,
            autofocus: true,
            style: AppFonts.barlowCondensed(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
            decoration: InputDecoration(
              labelText: 'Password',
              labelStyle: AppFonts.barlowCondensed(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textColor.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          key: const ValueKey('confirm-delete-account-button'),
          onPressed: _canDelete
              ? () => Navigator.of(context).pop(_password.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
            disabledBackgroundColor: const Color(
              0xFFB3261E,
            ).withValues(alpha: 0.4),
          ),
          child: const Text('DELETE'),
        ),
      ],
    );
  }
}
