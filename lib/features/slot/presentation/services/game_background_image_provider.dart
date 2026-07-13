import 'package:flutter/widgets.dart';

class GameBackgroundImageProvider {
  GameBackgroundImageProvider._();

  static const String normalAssetPath =
      'lib/images/slot_main_screen/nihai arka plan.png';
  static const String freeSpinAssetPath =
      'lib/images/slot_main_screen/freespin arka plan.png';

  static const int _normalSourceWidth = 1408;
  static const int _freeSpinSourceWidth = 1392;

  static ResizeImage resolve(
    BuildContext context, {
    required bool isFreeSpin,
  }) {
    final sourceWidth = isFreeSpin
        ? _freeSpinSourceWidth
        : _normalSourceWidth;
    final physicalWidth = View.of(context).physicalSize.width.ceil();
    final cacheWidth = physicalWidth.clamp(1, sourceWidth).toInt();
    final assetPath = isFreeSpin ? freeSpinAssetPath : normalAssetPath;

    return ResizeImage(AssetImage(assetPath), width: cacheWidth);
  }
}
