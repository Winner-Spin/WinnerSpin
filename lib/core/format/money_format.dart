/// Formats [amount] as a thousand-grouped money value with two decimals.
/// Example: 9875.5 → "9,875.50"; 1234567.89 → "1,234,567.89".
final RegExp _thousandsSeparatorPattern = RegExp(r'(\d)(?=(\d{3})+$)');

String formatMoney(double amount) {
  final fixed = amount.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    _thousandsSeparatorPattern,
    (match) => '${match[1]},',
  );
  return '$intPart.${parts[1]}';
}
