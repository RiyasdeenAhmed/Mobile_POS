/// Parses a decimal price without passing financial values through double.
int parseMoneyInput(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
        'Use a positive decimal with at most two decimal places');
  }
  final parts = value.split('.');
  final result = BigInt.parse(parts[0]) * BigInt.from(100) +
      (parts.length == 1 ? BigInt.zero : BigInt.parse(parts[1].padRight(2, '0')));
  if (result > BigInt.from(9000000000000)) {
    throw const FormatException('Amount is too large');
  }
  return result.toInt();
}
