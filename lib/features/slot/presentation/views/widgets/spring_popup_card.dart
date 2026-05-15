import 'package:flutter/material.dart';

class SpringPopupCard extends StatelessWidget {
  final Widget child;

  const SpringPopupCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (routeAnimation == null) return child;

    final scale = CurvedAnimation(
      parent: routeAnimation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.86, end: 1).animate(scale),
      child: child,
    );
  }
}
