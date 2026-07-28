import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../../../../core/typography/app_fonts.dart';
import '../../../../shared/widgets/spring_popup_card.dart';

/// First-launch gate: the player has to tick the acknowledgement before the
/// dialog can be dismissed.
///
/// The tick is what turns a notice nobody reads into a recorded confirmation —
/// it covers the "not real gambling" disclaimer, the policies, and the age
/// statement in one place, which is what the stores expect from a casino-themed
/// app.
class FirstLaunchDisclaimerDialog extends StatefulWidget {
  const FirstLaunchDisclaimerDialog({
    super.key,
    required this.onOkay,
    this.platform,
  });

  final VoidCallback onOkay;

  /// Overridable so tests can pin the platform the terms link depends on.
  final TargetPlatform? platform;

  static const String privacyPolicyUrl =
      'https://github.com/Winner-Spin/WinnerSpin/blob/main/PRIVACY_POLICY.md';
  static const String appleTermsUrl =
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

  @override
  State<FirstLaunchDisclaimerDialog> createState() =>
      _FirstLaunchDisclaimerDialogState();
}

class _FirstLaunchDisclaimerDialogState
    extends State<FirstLaunchDisclaimerDialog> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _linkColor = Color(0xFF1B6FB8);
  static const String _bodyText =
      'This project is created solely for entertainment and portfolio '
      'purposes. It does not offer real-money gambling, betting, cash prizes, '
      'or withdrawal services. All coins, spins, bonuses, and rewards included '
      'in this project are entirely virtual; they have no real-world monetary '
      'value and cannot be purchased, sold, or converted into money in any '
      'way. This project does not promote or encourage gambling or betting '
      'activities.';

  bool _accepted = false;

  final List<TapGestureRecognizer> _recognizers = [];

  bool get _usesAppleTerms {
    if (kIsWeb) return false;
    final platform = widget.platform ?? defaultTargetPlatform;
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The system back gesture would otherwise skip the acknowledgement
      // entirely, which is the one thing this dialog exists to collect.
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: SpringPopupCard(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.92,
                            // Taller than the plain notice was: the tick row
                            // and its link lines need the room.
                            maxHeight:
                                MediaQuery.of(context).size.height * 0.62,
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
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Column(
                                // Sized to its content instead of stretching
                                // to the height cap, which left a wide empty
                                // band under the button.
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildHeader(),
                                  Flexible(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        24,
                                        22,
                                        24,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            _bodyText,
                                            textAlign: TextAlign.center,
                                            style: AppFonts.barlowCondensed(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _textColor,
                                              height: 1.18,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          _buildAcknowledgement(),
                                          const SizedBox(height: 20),
                                          _buildOkayButton(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF6D7EB),
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Center(
        child: Text(
          'DISCLAIMER',
          style: AppFonts.barlowCondensed(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildAcknowledgement() {
    final baseStyle = AppFonts.barlowCondensed(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: _textColor,
      height: 1.25,
    );
    final linkStyle = baseStyle.copyWith(
      color: _linkColor,
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
      decorationColor: _linkColor,
    );

    return InkWell(
      key: const ValueKey('disclaimer-acknowledgement'),
      // The whole row toggles, not just the small box, so the tap target is
      // not a 20pt square.
      onTap: () => setState(() => _accepted = !_accepted),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                key: const ValueKey('disclaimer-checkbox'),
                value: _accepted,
                onChanged: (value) =>
                    setState(() => _accepted = value ?? false),
                activeColor: const Color(0xFF00C76A),
                checkColor: Colors.white,
                side: const BorderSide(color: _textColor, width: 2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    const TextSpan(
                      text: 'I have read and understood the notice above. '
                          'I confirm that I am 18 or older, and I accept the ',
                    ),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: linkStyle,
                      recognizer: _linkRecognizer(
                        FirstLaunchDisclaimerDialog.privacyPolicyUrl,
                      ),
                    ),
                    if (_usesAppleTerms) ...[
                      const TextSpan(text: ' and the '),
                      TextSpan(
                        text: 'Terms of Use',
                        style: linkStyle,
                        recognizer: _linkRecognizer(
                          FirstLaunchDisclaimerDialog.appleTermsUrl,
                        ),
                      ),
                    ],
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  TapGestureRecognizer _linkRecognizer(String url) {
    final recognizer = TapGestureRecognizer()..onTap = () => _openUrl(url);
    _recognizers.add(recognizer);
    return recognizer;
  }

  Future<void> _openUrl(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.platformDefault,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link could not be opened.')));
  }

  Widget _buildOkayButton() {
    // Disabled until the box is ticked: the point of the gate is that the
    // dialog cannot be dismissed without the confirmation.
    final enabled = _accepted;

    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        key: const ValueKey('disclaimer-okay'),
        onTap: enabled ? widget.onOkay : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Container(
            width: double.infinity,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled
                  ? const Color(0xFF00C76A)
                  : const Color(0xFF9AA39D),
              borderRadius: BorderRadius.circular(8),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              // Names the act rather than acknowledging a message: the tap is
              // the consent, so the label has to say so.
              'I ACCEPT',
              style: AppFonts.barlowCondensed(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
