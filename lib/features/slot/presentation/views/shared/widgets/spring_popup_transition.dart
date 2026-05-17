import 'package:flutter/material.dart';

Widget buildSpringPopupTransition(Animation<double> anim, Widget child) {
  final fade = CurvedAnimation(
    parent: anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  return FadeTransition(opacity: fade, child: child);
}
