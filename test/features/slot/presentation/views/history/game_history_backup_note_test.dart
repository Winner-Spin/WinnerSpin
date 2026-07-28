import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/repositories/game_history_repository.dart';
import 'package:winner_spin/features/slot/presentation/views/history/widgets/game_history_backup_note.dart';

void main() {
  testWidgets('states how many rounds the backup keeps', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameHistoryBackupNote(
            textColor: Color(0xFF2C2530),
            headerColor: Color(0xFFF6D7EB),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text)).data!;
    // Reads the cap instead of repeating it, so raising the limit cannot leave
    // the note telling players a number that is no longer true.
    expect(text, contains('$kMaxRemoteGameHistoryEntries rounds'));
    expect(text, contains('Restored from your account'));
  });
}
