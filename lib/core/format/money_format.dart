/// Formats [amount] as a comma-grouped currency string (e.g. "9,875.50").
String formatMoney(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );
  return '$intPart.${parts[1]}';
}
