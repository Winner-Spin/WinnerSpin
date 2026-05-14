/// One multiplier symbol that landed on the final grid. The position
/// lets the win-presentation layer fly the value out of the actual cell;
/// [value] is the raw face number (2, 3, 5, 10, 25, 50, 100).
class MultiplierLanding {
  final int column;
  final int row;
  final int value;

  const MultiplierLanding({
    required this.column,
    required this.row,
    required this.value,
  });
}
