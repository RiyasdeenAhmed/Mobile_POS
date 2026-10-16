enum PrinterConnectionState { unavailable, disconnected, connecting, connected, error }

class PrinterDevice {
  final String id;
  final String name;
  const PrinterDevice({required this.id, required this.name});
}

abstract interface class PrinterConnectionService {
  PrinterConnectionState get state;
  Future<List<PrinterDevice>> discover();
  Future<void> connect(PrinterDevice device);
  Future<void> disconnect();
  Future<void> testPrint();
}

class UnavailablePrinterConnectionService implements PrinterConnectionService {
  @override
  PrinterConnectionState get state => PrinterConnectionState.unavailable;

  @override
  Future<List<PrinterDevice>> discover() async => const [];

  @override
  Future<void> connect(PrinterDevice device) async =>
      throw StateError('Bluetooth printer support is unavailable');

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> testPrint() async =>
      throw StateError('Printer not configured');
}
