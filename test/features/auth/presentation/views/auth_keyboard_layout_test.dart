import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/audio/ambient_music_preference.dart';
import 'package:winner_spin/core/audio/ambient_music_preference_store.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/login_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/register_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/views/login_screen.dart';
import 'package:winner_spin/features/auth/presentation/views/register_screen.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  setUp(() async {
    AmbientMusicPreference.resetForTesting();
    await AmbientMusicPreference.initialize(store: _MusicDisabledStore());
  });
  tearDown(AmbientMusicPreference.resetForTesting);

  test('Android resizes the auth viewport so the page can scroll', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:windowSoftInputMode="adjustResize"'));
    expect(
      manifest,
      isNot(contains('android:windowSoftInputMode="adjustPan"')),
    );
  });

  testWidgets(
    'login centers tapped fields and shows a right-side scroll indicator',
    (tester) async {
      final viewModel = LoginViewModel.withRepository(FakeAuthRepository());
      addTearDown(viewModel.dispose);

      await _expectManualKeyboardScroll(
        tester,
        screen: LoginScreen(viewModel: viewModel),
        scrollbarKey: const ValueKey('login-screen-scrollbar'),
        scrollKey: const ValueKey('login-screen-scroll'),
        canvasKey: const ValueKey('login-screen-canvas'),
        backgroundAsset: 'lib/images/login_screen/background_1.png',
        initialFieldIndex: 0,
        targetFieldIndex: 1,
      );
    },
  );

  testWidgets('register centers password fields without hiding the keyboard', (
    tester,
  ) async {
    final viewModel = RegisterViewModel(authRepository: FakeAuthRepository());
    addTearDown(viewModel.dispose);

    await _expectManualKeyboardScroll(
      tester,
      screen: RegisterScreen(viewModel: viewModel),
      scrollbarKey: const ValueKey('register-screen-scrollbar'),
      scrollKey: const ValueKey('register-screen-scroll'),
      canvasKey: const ValueKey('register-screen-canvas'),
      backgroundAsset: 'lib/images/register_screen/register.png',
      initialFieldIndex: 2,
      targetFieldIndex: 3,
    );
  });
}

Future<void> _expectManualKeyboardScroll(
  WidgetTester tester, {
  required Widget screen,
  required Key scrollbarKey,
  required Key scrollKey,
  required Key canvasKey,
  required String backgroundAsset,
  required int initialFieldIndex,
  required int targetFieldIndex,
}) async {
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(1080, 1920);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();

  final scrollbar = find.byKey(scrollbarKey);
  final scrollView = find.byKey(scrollKey);
  final canvas = find.byKey(canvasKey);
  final background = find.image(AssetImage(backgroundAsset));
  final initialField = find.byType(TextField).at(initialFieldIndex);
  final targetField = find.byType(TextField).at(targetFieldIndex);

  final initialCanvasHeight = tester.getSize(canvas).height;
  final initialCanvasTop = tester.getTopLeft(canvas).dy;
  final initialBackgroundTop = tester.getTopLeft(background).dy;
  final initialFieldOffset =
      tester.getTopLeft(initialField).dy - initialCanvasTop;
  final initialTargetOffset =
      tester.getTopLeft(targetField).dy - initialCanvasTop;

  expect(tester.widget<RawScrollbar>(scrollbar).thumbVisibility, isFalse);
  final scrollWidget = tester.widget<SingleChildScrollView>(scrollView);
  expect(
    scrollWidget.keyboardDismissBehavior,
    ScrollViewKeyboardDismissBehavior.manual,
  );
  expect(scrollWidget.physics?.allowImplicitScrolling, isFalse);

  await tester.tap(initialField);
  await tester.pump();
  expect(tester.testTextInput.isVisible, isTrue);

  tester.view.viewInsets = const FakeViewPadding(bottom: 900);
  await tester.pump();
  await _pumpCenteringAnimation(tester);

  final keyboardCanvasTop = tester.getTopLeft(canvas).dy;
  expect(tester.getSize(canvas).height, closeTo(initialCanvasHeight, 0.01));
  expect(
    tester.getTopLeft(background).dy - keyboardCanvasTop,
    closeTo(initialBackgroundTop - initialCanvasTop, 0.01),
  );
  expect(
    tester.getTopLeft(initialField).dy - keyboardCanvasTop,
    closeTo(initialFieldOffset, 0.01),
  );
  expect(
    tester.getTopLeft(targetField).dy - keyboardCanvasTop,
    closeTo(initialTargetOffset, 0.01),
  );

  final scrollable = Scrollable.of(tester.element(canvas));
  expect(scrollable.position.maxScrollExtent, greaterThan(0));
  expect(scrollable.position.pixels, greaterThan(0));
  expect(
    tester.getCenter(initialField).dy,
    closeTo(tester.getCenter(scrollView).dy, 5),
  );

  final visibleScrollbar = tester.widget<RawScrollbar>(scrollbar);
  expect(visibleScrollbar.thumbVisibility, isTrue);
  expect(visibleScrollbar.trackVisibility, isFalse);
  expect(visibleScrollbar.scrollbarOrientation, ScrollbarOrientation.right);
  expect(visibleScrollbar.thumbColor, const Color(0xCC9E9E9E));
  expect(visibleScrollbar.thickness, 4);
  expect(visibleScrollbar.mainAxisMargin, 40);
  expect(visibleScrollbar.controller, same(scrollWidget.controller));

  final centeredOffset = scrollable.position.pixels;
  await tester.drag(scrollView, const Offset(0, -60));
  await tester.pump(const Duration(milliseconds: 250));

  final scrolledCanvasTop = tester.getTopLeft(canvas).dy;
  expect(scrollable.position.pixels, greaterThan(centeredOffset));
  expect(scrolledCanvasTop, lessThan(keyboardCanvasTop));
  expect(
    tester.getTopLeft(background).dy - scrolledCanvasTop,
    closeTo(initialBackgroundTop - initialCanvasTop, 0.01),
  );
  expect(
    tester.getTopLeft(targetField).dy - scrolledCanvasTop,
    closeTo(initialTargetOffset, 0.01),
  );
  expect(tester.testTextInput.isVisible, isTrue);

  await tester.tap(targetField);
  await tester.pump();
  await _pumpCenteringAnimation(tester);

  final targetWidget = tester.widget<TextField>(targetField);
  expect(targetWidget.focusNode?.hasFocus, isTrue);
  expect(tester.testTextInput.isVisible, isTrue);
  expect(
    tester.getCenter(targetField).dy,
    closeTo(tester.getCenter(scrollView).dy, 5),
  );

  tester.view.viewInsets = const FakeViewPadding();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
  expect(scrollable.position.maxScrollExtent, closeTo(0, 0.01));
  expect(tester.widget<RawScrollbar>(scrollbar).thumbVisibility, isFalse);
}

Future<void> _pumpCenteringAnimation(WidgetTester tester) async {
  for (int frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
}

class _MusicDisabledStore implements AmbientMusicPreferenceStore {
  @override
  Future<bool?> readEnabled() async => false;

  @override
  Future<void> writeEnabled(bool enabled) async {}
}
