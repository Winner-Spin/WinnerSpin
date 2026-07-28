import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../typography/app_fonts.dart';
import '../update/app_update_monitor.dart';

/// Blocks the app while a newer version is published on the store.
///
/// Mirrors [InternetRequiredGuard]: the child stays mounted but is made
/// non-interactive, and a full-screen prompt covers it.
class UpdateRequiredGuard extends StatelessWidget {
  const UpdateRequiredGuard({
    super.key,
    required this.monitor,
    required this.child,
  });

  final AppUpdateMonitor monitor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final isBlocked = monitor.status == AppUpdateStatus.updateRequired;

        return Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(absorbing: isBlocked, child: child),
            if (isBlocked)
              _UpdateRequiredOverlay(
                key: const ValueKey('update-required-overlay'),
                requiredVersion: monitor.requiredVersion,
                storeUrl: monitor.storeUrl,
              ),
          ],
        );
      },
    );
  }
}

class _UpdateRequiredOverlay extends StatelessWidget {
  const _UpdateRequiredOverlay({super.key, this.requiredVersion, this.storeUrl});

  final String? requiredVersion;
  final String? storeUrl;

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2C2530);
    const goldColor = Color(0xFFE5A800);

    // Mounted from `MaterialApp.builder`, above the Navigator, so there is no
    // Material ancestor to supply a DefaultTextStyle. Without this wrapper
    // Flutter paints every label with its yellow debug underline.
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: const Color(0xF218101F),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF6D7EB), Color(0xFFE2BED8)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: goldColor, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.42),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                      BoxShadow(
                        color: goldColor.withValues(alpha: 0.20),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: textColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: goldColor, width: 3),
                          ),
                          child: const Icon(
                            Icons.system_update_alt_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'UPDATE REQUIRED',
                          key: const ValueKey('update-required-title'),
                          textAlign: TextAlign.center,
                          style: AppFonts.barlowCondensed(
                            fontSize: 25,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: 0.8,
                            height: 1,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'A new version of Winner Spin is available. '
                          'Please update to keep playing.',
                          textAlign: TextAlign.center,
                          style: AppFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.82),
                            height: 1.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        if (requiredVersion != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'VERSION $requiredVersion',
                            key: const ValueKey('update-required-version'),
                            textAlign: TextAlign.center,
                            style: AppFonts.barlowCondensed(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: textColor.withValues(alpha: 0.62),
                              letterSpacing: 1,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        _UpdateButton(
                          onTap: () => _openStore(context),
                          textColor: textColor,
                          goldColor: goldColor,
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
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final url = storeUrl;
    if (url == null) return;

    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the App Store.')),
    );
  }
}

class _UpdateButton extends StatelessWidget {
  const _UpdateButton({
    required this.onTap,
    required this.textColor,
    required this.goldColor,
  });

  final VoidCallback onTap;
  final Color textColor;
  final Color goldColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: goldColor,
      shape: StadiumBorder(side: BorderSide(color: textColor, width: 2)),
      child: InkWell(
        key: const ValueKey('update-required-action'),
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 13),
          child: Text(
            'UPDATE NOW',
            textAlign: TextAlign.center,
            style: AppFonts.barlowCondensed(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.1,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
