import 'package:flutter/widgets.dart';

import '../models/win_tier.dart';

class BigWinHeadlineImageProvider {
  BigWinHeadlineImageProvider._();

  static const int _sourceWidth = 1254;

  static ResizeImage resolve(BuildContext context, WinTier tier) {
    final physicalWidth = View.of(context).physicalSize.width.ceil();
    final cacheWidth = physicalWidth.clamp(1, _sourceWidth).toInt();

    return ResizeImage(AssetImage(tier.assetPath), width: cacheWidth);
  }
}
