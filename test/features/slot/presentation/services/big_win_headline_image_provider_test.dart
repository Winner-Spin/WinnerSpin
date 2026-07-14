import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/models/win_tier.dart';
import 'package:winner_spin/features/slot/presentation/services/big_win_headline_image_provider.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/big_win_presentation_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/big_win/big_win_headline.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/big_win/big_win_overlay.dart';

void main() {
  testWidgets('uses the physical width for FHD Big Win headlines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = BigWinHeadlineImageProvider.resolve(
              context,
              WinTier.bigWin,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(provider.width, 1080);
  });

  testWidgets('caps QHD Big Win headlines at the source width', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = BigWinHeadlineImageProvider.resolve(
              context,
              WinTier.maxWin,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(provider.width, 1254);
  });

  testWidgets('renders the exact provider prepared for the selected tier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = BigWinHeadlineImageProvider.resolve(
              context,
              WinTier.epicWin,
            );
            return BigWinTierHeadline(
              tier: WinTier.epicWin,
              imageProvider: provider,
            );
          },
        ),
      ),
    );

    expect(tester.widget<Image>(find.byType(Image)).image, same(provider));
  });

  testWidgets('passes the selected tier provider into the Big Win overlay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);
    final overlayKey = GlobalKey<OverlayState>();
    final controller = BigWinPresentationController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Overlay(
          key: overlayKey,
          initialEntries: [
            OverlayEntry(builder: (context) => const SizedBox.expand()),
          ],
        ),
      ),
    );

    controller.maybeShow(
      amount: 10000,
      betAmount: 100,
      isBusy: false,
      overlay: overlayKey.currentState,
      speedMultiplier: 3,
      soundEnabled: false,
      vibrationEnabled: false,
      isMounted: () => true,
      setState: (callback) => callback(),
      onComplete: () {},
    );
    await tester.pump();

    final overlay = tester.widget<BigWinOverlay>(find.byType(BigWinOverlay));
    expect(overlay.tier, WinTier.epicWin);
    expect(overlay.headlineImage, isA<ResizeImage>());
    expect((overlay.headlineImage as ResizeImage).width, 1080);

    await tester.pump(const Duration(seconds: 12));
    controller.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
