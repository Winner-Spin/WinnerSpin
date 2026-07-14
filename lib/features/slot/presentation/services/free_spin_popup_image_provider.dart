import 'package:flutter/widgets.dart';

class FreeSpinPopupImageProvider {
  FreeSpinPopupImageProvider._();

  static const int _sourceWidth = 1024;
  static const double _screenWidthFactor = 0.88;

  static ResizeImage resolve(BuildContext context, String assetPath) {
    final physicalWidth = View.of(context).physicalSize.width;
    final cacheWidth = (physicalWidth * _screenWidthFactor)
        .ceil()
        .clamp(1, _sourceWidth)
        .toInt();

    return ResizeImage(AssetImage(assetPath), width: cacheWidth);
  }
}
