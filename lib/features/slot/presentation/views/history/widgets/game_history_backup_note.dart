import 'package:flutter/material.dart';

import '../../../../../../core/typography/app_fonts.dart';
import '../../../../domain/repositories/game_history_repository.dart';

/// Footnote shown under a history that was recovered from the account backup.
///
/// The device copy holds every spin, but the backup kept in the account only
/// stores the most recent ones. After a reinstall the player would otherwise
/// see a short list with no explanation and assume the rest was lost by
/// accident.
class GameHistoryBackupNote extends StatelessWidget {
  const GameHistoryBackupNote({
    super.key,
    required this.textColor,
    required this.headerColor,
  });

  final Color textColor;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 16,
            color: textColor.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Restored from your account. Only the last '
              '$kMaxRemoteGameHistoryEntries rounds are backed up, so older '
              'rounds from your previous install are not shown.',
              style: AppFonts.barlowCondensed(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.60),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
