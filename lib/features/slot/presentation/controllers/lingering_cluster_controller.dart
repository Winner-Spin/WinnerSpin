import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/models/cluster_win.dart';
import '../models/cluster_presentation_rules.dart';
import '../models/game_presentation_timings.dart';

class LingeringClusterController {
  ClusterWin? _cluster;
  ClusterWin? get cluster => _cluster;

  bool _wasTumbling = false;
  Timer? _timer;

  void clearForNewSpin({
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
  }) {
    _timer?.cancel();
    _timer = null;
    if (_cluster == null) return;
    if (!isMounted()) return;
    setState(() => _cluster = null);
  }

  void track({
    required List<ClusterWin> activeExplosions,
    required bool isTumbling,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
  }) {
    if (activeExplosions.isNotEmpty) {
      _timer?.cancel();
      _timer = null;
      final best = ClusterPresentationRules.highestAmount(activeExplosions);
      if (!identical(_cluster, best)) {
        setState(() => _cluster = best);
      }
    } else if (_wasTumbling && !isTumbling && _cluster != null) {
      _timer?.cancel();
      _timer = Timer(GamePresentationTimings.lingeringClusterHold, () {
        if (!isMounted()) return;
        setState(() => _cluster = null);
      });
    }
    _wasTumbling = isTumbling;
  }

  void dispose() {
    _timer?.cancel();
  }
}
