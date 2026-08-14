import 'package:flutter/widgets.dart';

/// Keeps keyboard focus from moving the page while preserving drag scrolling.
class ManualKeyboardScrollPhysics extends ClampingScrollPhysics {
  const ManualKeyboardScrollPhysics({super.parent});

  @override
  bool get allowImplicitScrolling => false;

  @override
  ManualKeyboardScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ManualKeyboardScrollPhysics(parent: buildParent(ancestor));
  }
}
