import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/symbol_registry.dart';
import '../models/game_presentation_timings.dart';
import '../views/game/widgets/presentation/big_win/big_win_overlay.dart';
import '../views/game/widgets/presentation/free_spins/free_spin_scatter_transition.dart';
import '../views/game/widgets/presentation/free_spins/free_spin_summary_popup.dart';
import '../views/game/widgets/presentation/free_spins/free_spin_win_popup.dart';
import '../views/game/widgets/playfield/multiplier_label.dart';
import 'free_spin_popup_image_provider.dart';
import 'game_background_image_provider.dart';

class GameAssetPrecacheService {
  Timer? _deferredSymbolTimer;
  ImageProvider? _freeSpinSummaryImage;

  void precacheInitialAssets({
    required BuildContext context,
    required List<List<String>> openingGrid,
    required bool Function() isMounted,
  }) {
    _precacheOpeningGridSymbols(context, openingGrid);
    _precacheMultiplierLabels(context);
    _precachePopupAssets(context);
    unawaited(FreeSpinScatterTransition.precacheCupcakeImage());
    _scheduleDeferredSymbolPrecache(
      context: context,
      openingGrid: openingGrid,
      isMounted: isMounted,
    );
    precacheImage(
      GameBackgroundImageProvider.resolve(context, isFreeSpin: true),
      context,
    );
  }

  void _precacheOpeningGridSymbols(
    BuildContext context,
    List<List<String>> openingGrid,
  ) {
    final openingPaths = <String>{for (final column in openingGrid) ...column};
    for (final path in openingPaths) {
      _precacheSymbol(context, path);
    }
  }

  void _scheduleDeferredSymbolPrecache({
    required BuildContext context,
    required List<List<String>> openingGrid,
    required bool Function() isMounted,
  }) {
    final openingPaths = <String>{for (final column in openingGrid) ...column};
    final remainingPaths = SymbolRegistry.all
        .map((symbol) => symbol.assetPath)
        .where((path) => !openingPaths.contains(path))
        .toList(growable: false);

    _deferredSymbolTimer?.cancel();
    _deferredSymbolTimer = Timer(
      GamePresentationTimings.deferredSymbolPrecacheDelay,
      () {
        unawaited(
          _precacheSymbolsInBatches(
            context: context,
            paths: remainingPaths,
            isMounted: isMounted,
          ),
        );
      },
    );
  }

  Future<void> _precacheSymbolsInBatches({
    required BuildContext context,
    required List<String> paths,
    required bool Function() isMounted,
  }) async {
    const batchSize = 3;
    for (var index = 0; index < paths.length; index += batchSize) {
      if (!isMounted()) return;
      final end = math.min(index + batchSize, paths.length);
      for (final path in paths.sublist(index, end)) {
        _precacheSymbol(context, path);
      }
      await Future<void>.delayed(
        GamePresentationTimings.symbolPrecacheBatchDelay,
      );
    }
  }

  void _precacheSymbol(BuildContext context, String path) {
    precacheImage(ResizeImage(AssetImage(path), width: 256), context);
  }

  void _precacheMultiplierLabels(BuildContext context) {
    for (final path in MultiplierLabel.assetPaths) {
      precacheImage(ResizeImage(AssetImage(path), width: 384), context);
    }
  }

  void _precachePopupAssets(BuildContext context) {
    precacheImage(
      const ResizeImage(
        AssetImage(BigWinOverlay.amountBannerAssetPath),
        width: BigWinOverlay.amountBannerCacheWidth,
      ),
      context,
    );
    precacheImage(
      FreeSpinPopupImageProvider.resolve(context, FreeSpinWinPopup.assetPath),
      context,
    );
  }

  Future<void> precacheFreeSpinSummary(BuildContext context) async {
    final image = FreeSpinPopupImageProvider.resolve(
      context,
      FreeSpinSummaryPopup.assetPath,
    );
    if (_freeSpinSummaryImage == image) return;

    final previousImage = _freeSpinSummaryImage;
    _freeSpinSummaryImage = image;
    if (previousImage != null) unawaited(previousImage.evict());

    await precacheImage(image, context);
    if (_freeSpinSummaryImage != image) {
      await image.evict();
    }
  }

  void evictFreeSpinSummary() {
    final image = _freeSpinSummaryImage;
    _freeSpinSummaryImage = null;
    if (image != null) unawaited(image.evict());
  }

  void dispose() {
    _deferredSymbolTimer?.cancel();
    _deferredSymbolTimer = null;
    evictFreeSpinSummary();
  }
}
