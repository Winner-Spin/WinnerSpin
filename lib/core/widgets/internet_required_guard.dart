import 'package:flutter/material.dart';
import '../typography/app_fonts.dart';

import '../network/internet_connection_monitor.dart';

class InternetRequiredGuard extends StatelessWidget {
  const InternetRequiredGuard({
    super.key,
    required this.monitor,
    required this.child,
  });

  final InternetConnectionMonitor monitor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final status = monitor.status;
        final isBlocked = status != InternetConnectionStatus.connected;

        return Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(absorbing: isBlocked, child: child),
            if (status == InternetConnectionStatus.disconnected)
              const _InternetRequiredOverlay(
                key: ValueKey('internet-required-overlay'),
              ),
          ],
        );
      },
    );
  }
}

class _InternetRequiredOverlay extends StatelessWidget {
  const _InternetRequiredOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFF2C2530);
    const goldColor = Color(0xFFE5A800);

    // This overlay is mounted from `MaterialApp.builder`, which sits above the
    // Navigator and therefore above every Scaffold. With no Material ancestor
    // there is no DefaultTextStyle, so Flutter falls back to its debug style
    // and paints every label with a yellow double underline. A transparent
    // Material supplies the theme text style without altering the visuals.
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
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'INTERNET CONNECTION REQUIRED',
                          key: const ValueKey('internet-required-title'),
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
                          'Winner Spin requires an active internet '
                          'connection. Turn on Wi-Fi or mobile data '
                          'to continue.',
                          textAlign: TextAlign.center,
                          style: AppFonts.barlowCondensed(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor.withValues(alpha: 0.82),
                            height: 1.25,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: textColor.withValues(alpha: 0.12),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'WAITING FOR CONNECTION...',
                                  style: AppFonts.barlowCondensed(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: textColor,
                                    letterSpacing: 0.5,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
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
      ),
    );
  }
}
