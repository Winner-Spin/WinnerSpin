import 'package:flutter/material.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../../domain/models/cluster_win.dart';

class FreeSpinInfoLine extends StatelessWidget {
  final ClusterWin? cluster;
  final int freeSpinsRemaining;
  final TextStyle style;

  const FreeSpinInfoLine({
    super.key,
    required this.cluster,
    required this.freeSpinsRemaining,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final clusterToShow = cluster;
    if (clusterToShow != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('${clusterToShow.positions.length}X', style: style),
          const SizedBox(width: 6),
          Image.asset(
            clusterToShow.assetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text('PAYS', style: style),
          const SizedBox(width: 3),
          MoneyText(
            text: formatMoney(clusterToShow.amount),
            style: style,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('FREE SPINS LEFT', style: style),
        const SizedBox(width: 6),
        Text('$freeSpinsRemaining', style: style),
      ],
    );
  }
}
