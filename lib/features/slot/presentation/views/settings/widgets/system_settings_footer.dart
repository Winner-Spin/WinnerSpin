import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../core/typography/app_fonts.dart';
import '../../../../../../core/update/app_build_info.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../audio/ui_click_sound.dart';

class SystemSettingsFooter extends StatelessWidget {
  const SystemSettingsFooter({super.key, this.platform});

  final TargetPlatform? platform;

  static const _privacyPolicyUrl =
      'https://sites.google.com/view/winner-spin-privacy-policy';
  static const _appleTermsUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
  static const _projectUrl = 'https://github.com/Winner-Spin/WinnerSpin';
  static const _hakanUrl = 'https://github.com/hakangunesdev';
  static const _enesUrl = 'https://github.com/eneseken95';
  static const supportEmail = 'winnerspinapp@gmail.com';
  static const _creditText = 'Made with \u2615\uFE0F & \u{1F4BB} by';
  // A fixed year, not `DateTime.now().year`: a copyright line should not follow
  // whatever the device clock happens to say. Bump it when the app ships in a
  // new year.
  static const _copyrightText =
      '\u00A9 2026 Hakan G\u00FCne\u015F & Enes Eken. All rights reserved.';
  static const _disclaimerText =
      'This project is created solely for entertainment and portfolio purposes. It does not offer real-money gambling, betting, cash prizes, or withdrawal services. All coins, spins, bonuses, and rewards included in this project are entirely virtual; they have no real-world monetary value and cannot be purchased, sold, or converted into money in any way. This project does not promote or encourage gambling or betting activities.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(color: Color(0x332C2530), height: 1),
        const SizedBox(height: 24),
        Text(
          // Covers everything below it: credits, source, legal links and the
          // support address. 'PROJECT & CREDITS' only described the first half.
          // Two words keeps the rhythm of 'GENERAL SETTINGS' / 'BET SETTINGS'.
          'ABOUT & SUPPORT',
          style: AppFonts.barlowCondensed(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF2C2530),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_creditText, style: _compactTextStyle(Colors.black)),
                const SizedBox(width: 6),
                _GitHubLink(
                  title: 'HAKAN GÜNEŞ',
                  onTap: () => _openUrl(context, _hakanUrl),
                ),
                const SizedBox(width: 6),
                Text('&', style: _compactTextStyle(Colors.black)),
                const SizedBox(width: 6),
                _GitHubLink(
                  title: 'ENES EKEN',
                  onTap: () => _openUrl(context, _enesUrl),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GitHubLink(
                  title: 'WINNER SPIN SOURCE CODE',
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.asset(
                      'assets/app_icon.png',
                      key: const ValueKey('winner-spin-source-app-icon'),
                      width: 16,
                      height: 16,
                      cacheWidth: 48,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  onTap: () => _openUrl(context, _projectUrl),
                ),
                const SizedBox(width: 8),
                _GitHubLink(
                  title: 'PRIVACY POLICY',
                  onTap: () => _openUrl(context, _privacyPolicyUrl),
                ),
                if (_usesAppleTerms) ...[
                  const SizedBox(width: 8),
                  _GitHubLink(
                    title: 'TERMS OF USE',
                    onTap: () => _openUrl(context, _appleTermsUrl),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _GitHubLink(
              title: supportEmail.toUpperCase(),
              leading: const Icon(
                Icons.mail_outline_rounded,
                size: 14,
                color: Color(0xFF2C2530),
              ),
              onTap: () => _openSupportEmail(context),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _disclaimerText,
          textAlign: TextAlign.center,
          style: AppFonts.barlowCondensed(
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.74),
            height: 1.08,
          ),
        ),
        const SizedBox(height: 12),
        // Shows the version the update check actually compares, so a debug
        // override is visible here too.
        Text(
          'VERSION $kAppVersion ($kAppBuildNumber)',
          key: const ValueKey('settings-app-version'),
          textAlign: TextAlign.center,
          style: AppFonts.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.black.withValues(alpha: 0.45),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        // Last line on the screen, where a copyright notice is expected.
        Text(
          _copyrightText,
          key: const ValueKey('settings-copyright'),
          textAlign: TextAlign.center,
          style: AppFonts.barlowCondensed(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.40),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  bool get _usesAppleTerms {
    if (kIsWeb) return false;
    final currentPlatform = platform ?? defaultTargetPlatform;
    return currentPlatform == TargetPlatform.iOS ||
        currentPlatform == TargetPlatform.macOS;
  }

  TextStyle _compactTextStyle(Color color) {
    return AppFonts.barlowCondensed(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: 0.3,
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    UiClickSound.play();

    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
      );
      if (!opened && context.mounted) {
        _showOpenLinkError(context);
      }
    } catch (_) {
      if (context.mounted) {
        _showOpenLinkError(context);
      }
    }
  }

  /// Opens the device mail composer at [supportEmail].
  ///
  /// Plenty of devices have no mail client configured, in which case `mailto:`
  /// silently does nothing. Copying the address to the clipboard and showing it
  /// keeps the tap useful instead of looking broken.
  Future<void> _openSupportEmail(BuildContext context) async {
    UiClickSound.play();

    // No prefilled subject: the composer opens with an empty subject line.
    final uri = Uri(scheme: 'mailto', path: supportEmail);

    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;

    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email address copied: $supportEmail')),
    );
  }

  void _showOpenLinkError(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link could not be opened.')));
  }
}

class _GitHubLink extends StatelessWidget {
  const _GitHubLink({required this.title, required this.onTap, this.leading});

  final String title;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2C2530);
    final label = Text(
      title,
      textAlign: TextAlign.center,
      style: AppFonts.barlowCondensed(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.3,
      ),
    );

    return Material(
      color: Colors.white.withValues(alpha: 0.46),
      shape: StadiumBorder(
        side: BorderSide(color: textColor.withValues(alpha: 0.16)),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 5)],
              label,
            ],
          ),
        ),
      ),
    );
  }
}
