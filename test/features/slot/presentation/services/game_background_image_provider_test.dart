import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/services/game_background_image_provider.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/layout/game_background.dart';

void main() {
  testWidgets('uses the physical view width on FHD displays', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage provider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            provider = GameBackgroundImageProvider.resolve(
              context,
              isFreeSpin: false,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(provider.width, 1080);
  });

  testWidgets('caps QHD decoding at each source image width', (tester) async {
    tester.view.physicalSize = const Size(1440, 3120);
    addTearDown(tester.view.resetPhysicalSize);

    late ResizeImage normalProvider;
    late ResizeImage freeSpinProvider;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            normalProvider = GameBackgroundImageProvider.resolve(
              context,
              isFreeSpin: false,
            );
            freeSpinProvider = GameBackgroundImageProvider.resolve(
              context,
              isFreeSpin: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(normalProvider.width, 1408);
    expect(freeSpinProvider.width, 1392);
  });

  testWidgets('returns matching providers for precache and rendering', (
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
            precacheProvider = GameBackgroundImageProvider.resolve(
              context,
              isFreeSpin: true,
            );
            renderProvider = GameBackgroundImageProvider.resolve(
              context,
              isFreeSpin: true,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(precacheProvider, renderProvider);
  });

  testWidgets('game background uses medium filtering and the shared provider', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2340);
    addTearDown(tester.view.resetPhysicalSize);
    final visualMode = ValueNotifier<bool>(false);
    addTearDown(visualMode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: GameBackground(
          listenable: visualMode,
          isFreeSpinVisualMode: () => visualMode.value,
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 1080);
    expect(image.filterQuality, FilterQuality.medium);
  });
}
