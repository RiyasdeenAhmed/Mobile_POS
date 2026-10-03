import '../../../core/database/settings_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../domain/receipt.dart';
import 'escpos_builder.dart';
import 'printer_service.dart';

/// Loads receipt settings, builds a [Receipt], and sends ESC/POS bytes to
/// the printer. Failures surface as [PrinterException] to the caller; the
/// sale itself is never touched (printing is post-commit).
class ReceiptPrintService {
  final PrinterService printer;
  final SettingsRepository settings;
  final CustomerRepository customers;

  ReceiptPrintService({
    required this.printer,
    required this.settings,
    required this.customers,
  });

  Future<bool> autoPrintEnabled() async =>
      await settings.getStringOrDefault('auto_print_receipt', '0') == '1';

  Future<Receipt> buildReceipt({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    final map = await settings.loadCoreSettings();
    String? customerName;
    if (sale.customerId != null) {
      customerName = (await customers.findById(sale.customerId!))?.name;
    }
    return Receipt.fromSale(
      sale: sale,
      items: items,
      settings: map,
      cashierName: cashierName,
      customerName: customerName,
    );
  }

  Future<List<int>> receiptBytes({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    final receipt = await buildReceipt(
      sale: sale,
      items: items,
      cashierName: cashierName,
    );
    final width = int.tryParse(
          await settings.getStringOrDefault('printer_width', '32'),
        ) ??
        32;
    return buildEscPosReceipt(receipt, width: width);
  }

  Future<void> printSale({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    final bytes = await receiptBytes(
      sale: sale,
      items: items,
      cashierName: cashierName,
    );
    try {
      await printer.print(bytes);
    } on PrinterException {
      rethrow;
    } catch (error) {
      throw PrinterException('Printing failed: $error');
    }
  }
}
