/// Printing is a post-commit action: never part of the sale transaction.
abstract interface class PrinterService {
  Future<void> print(List<int> job);
}

class PrinterException implements Exception {
  final String message;

  const PrinterException(this.message);

  @override
  String toString() => 'PrinterException: $message';
}

class UnconfiguredPrinter implements PrinterService {
  @override
  Future<void> print(List<int> job) async {
    throw const PrinterException('Printer not configured');
  }
}
