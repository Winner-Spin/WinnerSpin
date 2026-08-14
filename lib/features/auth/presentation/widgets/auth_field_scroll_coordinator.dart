import 'dart:async';

import 'package:flutter/widgets.dart';

/// Centers a tapped authentication field after the keyboard viewport settles.
class AuthFieldScrollCoordinator {
  final ScrollController controller = ScrollController();

  int _requestId = 0;
  bool _disposed = false;

  void centerField(GlobalKey fieldKey) {
    final requestId = ++_requestId;
    unawaited(_centerWhenScrollable(fieldKey, requestId));
  }

  Future<void> _centerWhenScrollable(GlobalKey fieldKey, int requestId) async {
    double? previousExtent;
    int stableSamples = 0;

    // The keyboard can report several viewport sizes while opening. Waiting
    // for a stable scroll extent prevents centering against an intermediate
    // keyboard animation frame.
    for (int attempt = 0; attempt < 40; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (_disposed || requestId != _requestId) return;
      if (!controller.hasClients) continue;

      final position = controller.position;
      if (!position.hasContentDimensions || position.maxScrollExtent <= 0) {
        continue;
      }

      final extent = position.maxScrollExtent;
      if (previousExtent != null && (extent - previousExtent).abs() < 0.5) {
        stableSamples++;
      } else {
        stableSamples = 0;
      }
      previousExtent = extent;

      if (stableSamples < 2) continue;
      final fieldContext = fieldKey.currentContext;
      if (fieldContext == null || !fieldContext.mounted) return;

      await Scrollable.ensureVisible(
        fieldContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }
  }

  void dispose() {
    _disposed = true;
    _requestId++;
    controller.dispose();
  }
}
