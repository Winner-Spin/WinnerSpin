import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../domain/models/slot_symbol.dart';
import '../../../domain/models/symbol_registry.dart';
import '../../audio/ui_click_sound.dart';
import '../../viewmodels/game_viewmodel.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  final GameViewModel viewModel;
  final VoidCallback onClose;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _goldColor = Color(0xFFE5A800);

  String? _savingAvatarId;
  bool _showAvatarOptions = false;
  bool _isSendingReset = false;
  bool _isDeletingAccount = false;
  bool _isSigningOut = false;
  bool _resetSentInCurrentSession = false;
  String? _statusMessage;
  bool _statusIsError = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showAvatarOptions,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _showAvatarOptions) _returnToProfile();
      },
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 18),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.92,
                      maxHeight: MediaQuery.of(context).size.height * 0.84,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _panelColor,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          _buildHeader(),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: widget.viewModel,
                              builder: (context, _) => _showAvatarOptions
                                  ? _buildAvatarGrid()
                                  : _buildProfileContent(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        _buildIdentity(),
        const SizedBox(height: 28),
        const Divider(color: Color(0x332C2530), height: 1),
        const SizedBox(height: 24),
        _sectionTitle('MY ACCOUNT'),
        const SizedBox(height: 14),
        _buildAccountCard(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: const BoxDecoration(
        color: _headerColor,
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _circleButton(
              key: const ValueKey('profile-header-back-button'),
              icon: Icons.arrow_back_rounded,
              onTap: _showAvatarOptions ? _returnToProfile : _close,
            ),
          ),
          Text(
            _showAvatarOptions ? 'SELECT AVATAR' : 'MY PROFILE',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _panelAccent.withValues(alpha: 0.88),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 29, color: _textColor),
      ),
    );
  }

  Widget _buildIdentity() {
    final selectedSymbol =
        SymbolRegistry.byId(widget.viewModel.profileAvatarId) ??
        SymbolRegistry.byId(SymbolRegistry.defaultProfileAvatarId)!;

    return Column(
      children: [
        SizedBox(
          width: 108,
          height: 108,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    shape: BoxShape.circle,
                    border: Border.all(color: _goldColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: _goldColor.withValues(alpha: 0.20),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    selectedSymbol.assetPath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                right: 3,
                bottom: 3,
                child: Semantics(
                  button: true,
                  label: 'Change profile avatar',
                  child: InkWell(
                    key: const ValueKey('select-avatar-button'),
                    customBorder: const CircleBorder(),
                    onTap: _openAvatarOptions,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _textColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: _headerColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.24),
                            blurRadius: 7,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 19,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.viewModel.username,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.viewModel.email,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _textColor.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.barlowCondensed(
        fontSize: 19,
        fontWeight: FontWeight.w900,
        color: _textColor,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildAvatarGrid() {
    final avatars = SymbolRegistry.profileAvatars;
    return GridView.builder(
      key: const ValueKey('profile-avatar-list'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      itemCount: avatars.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.76,
      ),
      itemBuilder: (context, index) => _buildAvatarOption(avatars[index]),
    );
  }

  Widget _buildAvatarOption(SlotSymbol symbol) {
    final selected = widget.viewModel.profileAvatarId == symbol.id;
    final saving = _savingAvatarId == symbol.id;

    return Semantics(
      button: true,
      selected: selected,
      label: 'Avatar ${symbol.id}',
      child: InkWell(
        key: ValueKey('profile-avatar-${symbol.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: _savingAvatarId == null ? () => _selectAvatar(symbol.id) : null,
        child: Column(
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.58)
                      : _panelAccent.withValues(alpha: 0.54),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? _goldColor
                        : _textColor.withValues(alpha: 0.10),
                    width: selected ? 3 : 1.5,
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(symbol.assetPath, fit: BoxFit.contain),
                    if (saving)
                      const Positioned.fill(
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: _goldColor,
                        ),
                      ),
                    if (selected && !saving)
                      const Positioned(
                        right: 0,
                        bottom: 0,
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: _goldColor,
                          size: 21,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _avatarLabel(symbol.id),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: _textColor,
                letterSpacing: 0.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _avatarLabel(String id) => id.replaceAll('_', ' ').toUpperCase();

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _textColor.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'FIRESTORE EMAIL',
            style: GoogleFonts.barlowCondensed(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: _textColor.withValues(alpha: 0.52),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            widget.viewModel.email,
            style: GoogleFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSendingReset || _resetSentInCurrentSession
                ? null
                : _sendPasswordReset,
            style: FilledButton.styleFrom(
              backgroundColor: _textColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _textColor.withValues(alpha: 0.45),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isSendingReset
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    _resetSentInCurrentSession
                        ? Icons.mark_email_read_rounded
                        : Icons.lock_reset_rounded,
                  ),
            label: Text(
              _isSendingReset
                  ? 'SENDING...'
                  : _resetSentInCurrentSession
                  ? 'RESET EMAIL SENT'
                  : 'RESET PASSWORD',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _statusIsError
                    ? const Color(0xFFB3261E)
                    : const Color(0xFF247A3D),
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Divider(color: Color(0x332C2530), height: 1),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('delete-account-button'),
            onPressed: _accountActionInProgress ? null : _confirmDeleteAccount,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB3261E),
              side: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isDeletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFFB3261E),
                    ),
                  )
                : const Icon(Icons.delete_forever_rounded),
            label: Text(
              _isDeletingAccount ? 'DELETING ACCOUNT...' : 'DELETE ACCOUNT',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('log-out-button'),
            onPressed: _accountActionInProgress ? null : _signOut,
            style: FilledButton.styleFrom(
              backgroundColor: _textColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _textColor.withValues(alpha: 0.45),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(
              _isSigningOut ? 'LOGGING OUT...' : 'LOG OUT',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _accountActionInProgress => _isDeletingAccount || _isSigningOut;

  Future<void> _selectAvatar(String avatarId) async {
    UiClickSound.play();
    setState(() {
      _savingAvatarId = avatarId;
      _statusMessage = null;
    });
    final saved = await widget.viewModel.selectProfileAvatar(avatarId);
    if (!mounted) return;
    setState(() {
      _savingAvatarId = null;
      if (!saved) {
        _statusIsError = true;
        _statusMessage = 'Avatar could not be saved. Please try again.';
      }
    });
  }

  Future<void> _sendPasswordReset() async {
    UiClickSound.play();
    setState(() {
      _isSendingReset = true;
      _statusMessage = null;
    });
    try {
      await widget.viewModel.sendPasswordResetEmail();
      if (!mounted) return;
      setState(() {
        _statusIsError = false;
        _resetSentInCurrentSession = true;
        _statusMessage =
            'Password reset email sent. After changing your password, return '
            'to the app and sign in with your new password. You can request '
            'it once every 24 hours.';
      });
    } on PasswordResetLimitException catch (error) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage =
            'Only one password reset is allowed every 24 hours. '
            'Try again after ${_formatRetryTime(error.nextAllowedAt)}.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Reset email could not be sent. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    UiClickSound.play();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _headerColor,
        title: Text(
          'DELETE ACCOUNT?',
          style: GoogleFonts.barlowCondensed(
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        content: Text(
          'This permanently deletes your account and game data. '
          'This action cannot be undone.',
          style: GoogleFonts.barlowCondensed(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _textColor,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-account-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeletingAccount = true;
      _statusMessage = null;
    });
    try {
      await widget.viewModel.deleteAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Account could not be deleted. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<void> _signOut() async {
    UiClickSound.play();
    setState(() {
      _isSigningOut = true;
      _statusMessage = null;
    });
    try {
      await widget.viewModel.signOut();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = 'Log out failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  void _close() {
    UiClickSound.play();
    widget.onClose();
  }

  void _openAvatarOptions() {
    UiClickSound.play();
    setState(() => _showAvatarOptions = true);
  }

  void _returnToProfile() {
    UiClickSound.play();
    setState(() => _showAvatarOptions = false);
  }

  String _formatRetryTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month $hour:$minute';
  }
}
