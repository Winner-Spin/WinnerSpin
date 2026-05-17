import 'package:flutter/animation.dart';

class HeftyBounceCurve extends Curve {
  const HeftyBounceCurve();

  @override
  double transformInternal(double t) {
    final t1 = t - 1.0;
    const s = 1.35;
    return t1 * t1 * ((s + 1.0) * t1 + s) + 1.0;
  }
}
