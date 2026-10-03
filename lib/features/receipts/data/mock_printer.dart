import 'printer_service.dart';

/// Default in-memory printer: captures jobs for assertions. Set [fail] to
/// simulate an offline/unreachable printer.
class MockPrinter implements PrinterService {
  final List<List<int>> jobs = <List<int>>[];
  bool fail;

  MockPrinter({this.fail = false});

  @override
  Future<void> print(List<int> job) async {
    if (fail) {
      throw const PrinterException('Printer is unavailable');
    }
    jobs.add(List<int>.unmodifiable(job));
  }
}
