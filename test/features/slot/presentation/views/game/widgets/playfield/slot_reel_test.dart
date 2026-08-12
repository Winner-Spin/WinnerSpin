import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/playfield/slot_reel.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/playfield/slot_reel_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/playfield/tumble_cell.dart';

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

  testWidgets(
    'early quick stop waits for the current target and completes once',
    (tester) async {
      final symbols = SymbolRegistry.all
          .where((symbol) => symbol.isRegular)
          .take(3)
          .map((symbol) => symbol.assetPath)
          .toList();
      final harnessKey = GlobalKey<_QuickStopHarnessState>();
      var completions = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _QuickStopHarness(
              key: harnessKey,
              oldPath: symbols[0],
              onComplete: () => completions++,
            ),
          ),
        ),
      );

      harnessKey.currentState!.startPendingSpin();
      await tester.pump();
      harnessKey.currentState!
        ..quickStop()
        ..quickStop();
      await tester.pump();

      // A stale-target quick stop would finish its 260 ms drop-in here.
      await tester.pump(const Duration(milliseconds: 300));
      expect(completions, 0);

      final publishedItems = harnessKey.currentState!.publishTarget(symbols[1]);
      await tester.pump();

      final landingImages = tester
          .widgetList<Image>(
            find.descendant(
              of: find.byType(SlotReel),
              matching: find.byType(Image),
            ),
          )
          .toList();
      expect(landingImages, hasLength(SlotEngine.rows));
      for (var row = 0; row < SlotEngine.rows; row++) {
        expect(
          find.byKey(ValueKey('reel-symbol-0-$row-1-${symbols[1]}-false')),
          findsOneWidget,
        );
        expect(
          find.byKey(ValueKey('reel-symbol-0-$row-1-${symbols[0]}-false')),
          findsNothing,
        );
      }
      expect(
        landingImages.map((image) => image.gaplessPlayback).toList(),
        List<bool>.filled(SlotEngine.rows, false),
      );

      // Mutating the source list must not change the active landing snapshot.
      publishedItems.setAll(
        0,
        List<String>.filled(SlotEngine.rows, symbols[2]),
      );
      harnessKey.currentState!
        ..quickStop()
        ..quickStop();

      await tester.pump(const Duration(milliseconds: 259));
      expect(completions, 0);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();

      expect(completions, 1);
      final landedCells = tester
          .widgetList<TumbleCell>(find.byType(TumbleCell))
          .toList();
      expect(landedCells, hasLength(SlotEngine.rows));
      expect(landedCells.map((cell) => cell.path), everyElement(symbols[1]));
      expect(landedCells.map((cell) => cell.path), isNot(contains(symbols[2])));

      harnessKey.currentState!.quickStop();
      await tester.pump(const Duration(seconds: 3));
      expect(completions, 1);
    },
  );

  testWidgets('quick stop survives a request before the spin frame', (
    tester,
  ) async {
    final symbols = SymbolRegistry.all
        .where((symbol) => symbol.isRegular)
        .take(2)
        .map((symbol) => symbol.assetPath)
        .toList();
    final harnessKey = GlobalKey<_QuickStopHarnessState>();
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _QuickStopHarness(
            key: harnessKey,
            oldPath: symbols[0],
            onComplete: () => completions++,
          ),
        ),
      ),
    );

    harnessKey.currentState!
      ..startPendingSpin()
      ..quickStop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(completions, 0);

    harnessKey.currentState!.publishTarget(symbols[1]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 259));
    expect(completions, 0);
    await tester.pump(const Duration(milliseconds: 2));
    await tester.pump();

    expect(completions, 1);
    expect(
      tester
          .widgetList<TumbleCell>(find.byType(TumbleCell))
          .map((cell) => cell.path),
      everyElement(symbols[1]),
    );
  });

  testWidgets('a stale quick stop cannot complete a newer spin', (
    tester,
  ) async {
    final symbols = SymbolRegistry.all
        .where((symbol) => symbol.isRegular)
        .take(2)
        .map((symbol) => symbol.assetPath)
        .toList();
    final harnessKey = GlobalKey<_QuickStopHarnessState>();
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _QuickStopHarness(
            key: harnessKey,
            oldPath: symbols[0],
            onComplete: () => completions++,
          ),
        ),
      ),
    );

    harnessKey.currentState!.startPendingSpin();
    await tester.pump();
    harnessKey.currentState!.quickStopRevision(1);

    // Start the next revision while the previous run is still waiting for its
    // target. Its completer and animation callbacks must become stale.
    harnessKey.currentState!.startPendingSpin();
    await tester.pump();
    harnessKey.currentState!.quickStopRevision(1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(completions, 0);

    harnessKey.currentState!.publishTarget(symbols[1]);
    await tester.pump();
    harnessKey.currentState!.quickStopRevision(2);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 261));
    await tester.pump();

    expect(completions, 1);
    expect(
      tester
          .widgetList<TumbleCell>(find.byType(TumbleCell))
          .map((cell) => cell.path),
      everyElement(symbols[1]),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(completions, 1);
  });

  testWidgets('normal landing also waits for a delayed target', (tester) async {
    final symbols = SymbolRegistry.all
        .where((symbol) => symbol.isRegular)
        .take(2)
        .map((symbol) => symbol.assetPath)
        .toList();
    final harnessKey = GlobalKey<_QuickStopHarnessState>();
    var completions = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _QuickStopHarness(
            key: harnessKey,
            oldPath: symbols[0],
            onComplete: () => completions++,
          ),
        ),
      ),
    );

    harnessKey.currentState!.startPendingSpin();
    await tester.pump();
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(completions, 0);
    expect(find.byType(TumbleCell), findsNothing);

    harnessKey.currentState!.publishTarget(symbols[1]);
    await tester.pump();
    for (var frame = 0; frame < 30 && completions == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(completions, 1);
    expect(
      tester
          .widgetList<TumbleCell>(find.byType(TumbleCell))
          .map((cell) => cell.path),
      everyElement(symbols[1]),
    );
  });
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
  int _targetReadyRevision = 0;

  void startSpin() {
    setState(() {
      _spinning = true;
      _spinRevision++;
      _targetReadyRevision = _spinRevision;
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
        targetReadyRevision: _targetReadyRevision,
        speedMultiplier: 3,
        soundEffectsEnabled: false,
        onComplete: widget.onComplete,
      ),
    );
  }
}

class _QuickStopHarness extends StatefulWidget {
  const _QuickStopHarness({
    super.key,
    required this.oldPath,
    required this.onComplete,
  });

  final String oldPath;
  final VoidCallback onComplete;

  @override
  State<_QuickStopHarness> createState() => _QuickStopHarnessState();
}

class _QuickStopHarnessState extends State<_QuickStopHarness> {
  final SlotReelController _controller = SlotReelController();
  late List<String> _targetItems = List<String>.filled(
    SlotEngine.rows,
    widget.oldPath,
  );
  bool _spinning = false;
  int _spinRevision = 0;
  int _targetReadyRevision = 0;

  void startPendingSpin() {
    setState(() {
      _spinning = true;
      _spinRevision++;
    });
  }

  List<String> publishTarget(String path) {
    final items = List<String>.filled(SlotEngine.rows, path);
    setState(() {
      _targetItems = items;
      _targetReadyRevision = _spinRevision;
    });
    return items;
  }

  void quickStop() => _controller.quickStop(_spinRevision);

  void quickStopRevision(int spinRevision) =>
      _controller.quickStop(spinRevision);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 300,
      child: SlotReel(
        columnIndex: 0,
        controller: _controller,
        previousItems: List<String>.filled(SlotEngine.rows, widget.oldPath),
        targetItems: _targetItems,
        spinning: _spinning,
        spinRevision: _spinRevision,
        targetReadyRevision: _targetReadyRevision,
        soundEffectsEnabled: false,
        onComplete: widget.onComplete,
      ),
    );
  }
}
