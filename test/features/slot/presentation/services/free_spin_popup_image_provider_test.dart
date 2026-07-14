import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/services/free_spin_popup_image_provider.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/free_spins/free_spin_summary_popup.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/free_spins/free_spin_win_popup.dart';

void main() {
  testWidgets('sizes Free Spin popup decoding for FHD displays', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = FreeSpinPopupImageProvider.resolve(
              context,
              FreeSpinWinPopup.assetPath,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(provider.width, 951);
  });

  testWidgets('caps QHD Free Spin popup decoding at the source width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 3120);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = FreeSpinPopupImageProvider.resolve(
              context,
              FreeSpinSummaryPopup.assetPath,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(provider.width, 1024);
  });

  testWidgets('returns matching providers for precaching and rendering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage precacheProvider;
    late ResizeImage renderProvider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            precacheProvider = FreeSpinPopupImageProvider.resolve(
              context,
              FreeSpinSummaryPopup.assetPath,
            );
            renderProvider = FreeSpinPopupImageProvider.resolve(
              context,
              FreeSpinSummaryPopup.assetPath,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(precacheProvider, renderProvider);
  });
}
