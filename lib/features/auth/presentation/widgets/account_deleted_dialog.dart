import 'package:flutter/material.dart';

import '../../../../core/typography/app_fonts.dart';
import '../../../slot/presentation/views/shared/widgets/spring_popup_card.dart';

class AccountDeletedDialog extends StatelessWidget {
  const AccountDeletedDialog({super.key});

  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _successColor = Color(0xFF247A3D);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('account-deleted-dialog'),
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: SpringPopupCard(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 76,
                          color: _successColor,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Your account and associated data have been deleted.',
                          textAlign: TextAlign.center,
                          style: AppFonts.barlowCondensed(
                            fontSize: 18,
                            height: 1.25,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const ValueKey('account-deleted-ok-button'),
                          onPressed: () => Navigator.of(context).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: _textColor,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: Text(
                            'OK',
                            style: AppFonts.barlowCondensed(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
            'ACCOUNT DELETED',
            style: AppFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                key: const ValueKey('account-deleted-close-button'),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: _panelColor.withValues(alpha: 0.88),
                ),
                icon: const Icon(Icons.close, size: 30, color: _textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
