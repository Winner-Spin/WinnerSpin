import 'package:flutter/material.dart';

class FooterClockText extends StatelessWidget {
  final TextStyle style;

  const FooterClockText({super.key, required this.style});

  static final Stream<DateTime> _ticker = Stream<DateTime>.periodic(
    const Duration(seconds: 10),
    (_) => DateTime.now().toUtc().add(const Duration(hours: 3)),
  ).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _ticker,
      initialData: DateTime.now().toUtc().add(const Duration(hours: 3)),
      builder: (context, snapshot) {
        final now = snapshot.data!;
        final timeString =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        final separator = String.fromCharCode(0x00B7);
        return Text(
          'WINNER SPIN $separator $timeString',
          textAlign: TextAlign.center,
          style: style,
        );
      },
    );
  }
}
