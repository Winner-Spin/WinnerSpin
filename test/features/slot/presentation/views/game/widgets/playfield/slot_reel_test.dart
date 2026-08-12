import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/playfield/slot_reel.dart';

void main() {
  testWidgets(
    'a new spin revision restarts a reel that still sees spinning true',
    (tester) async {
      final harnessKey = GlobalKey<_ReelHarnessState>();
      var completions = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: _ReelHarness(
                key: harnessKey,
                onComplete: () => completions++,
              ),
            ),
          ),
        ),
      );

      harnessKey.currentState!.startSpin();
      await _finishReelAnimation(tester);
      expect(completions, 1);

      // Deliberately keep `spinning` true. The revision is the reliable event
      // identity when a false frame was not rendered between consecutive spins.
      harnessKey.currentState!.startSpin();
      await _finishReelAnimation(tester);
      expect(completions, 2);
    },
  );
}

Future<void> _finishReelAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 500));
}

class _ReelHarness extends StatefulWidget {
  const _ReelHarness({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<_ReelHarness> createState() => _ReelHarnessState();
}

class _ReelHarnessState extends State<_ReelHarness> {
  final String _symbolPath = SymbolRegistry.all
      .firstWhere((symbol) => symbol.isRegular)
      .assetPath;
  bool _spinning = false;
  int _spinRevision = 0;

  void startSpin() {
    setState(() {
      _spinning = true;
      _spinRevision++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = List.filled(SlotEngine.rows, _symbolPath);
    return SizedBox(
      width: 120,
      height: 300,
      child: SlotReel(
        columnIndex: 0,
        previousItems: items,
        targetItems: items,
        spinning: _spinning,
        spinRevision: _spinRevision,
        speedMultiplier: 3,
        soundEffectsEnabled: false,
        onComplete: widget.onComplete,
      ),
    );
  }
}
