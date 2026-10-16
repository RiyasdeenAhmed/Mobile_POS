import '../../payments/domain/payment.dart';
import '../../sales/data/sale_repository.dart';
import '../../staff/data/staff_repository.dart';
import '../../../core/database/settings_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../domain/receipt.dart';
import 'escpos_builder.dart';
import 'printer_service.dart';
import 'tspl_builder.dart';
import 'android_bluetooth_printer.dart';

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
    final payments = sale.id == null
        ? <Payment>[]
        : await SaleRepository(settings.database).listPayments(sale.id!);
    final staff = sale.staffUuid == null
        ? null
        : await StaffRepository(settings.database).findByUuid(sale.staffUuid!);
    return Receipt.fromSale(
      payments: payments,
      sale: sale,
      items: items,
      settings: map,
      cashierName: staff?.displayName ?? cashierName,
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
    final widthSetting = int.tryParse(
          await settings.getStringOrDefault('printer_width', '42'),
        ) ??
        32;
    final widthMm = widthSetting == 42 || widthSetting == 80 ? 80 : 58;
    final horizontalOffsetDots = int.tryParse(
          await settings.getStringOrDefault('printer_offset_dots', '0'),
        ) ??
        0;
    final contentWidthDots = int.tryParse(
          await settings.getStringOrDefault(
            'printer_content_width_dots',
            widthMm == 80 ? '608' : '432',
          ),
        ) ??
        (widthMm == 80 ? 608 : 432);
    final logoWidthDots = int.tryParse(
          await settings.getStringOrDefault(
            'printer_logo_width_dots',
            widthMm == 80 ? '360' : '260',
          ),
        ) ??
        (widthMm == 80 ? 360 : 260);
    final fontScale = int.tryParse(
          await settings.getStringOrDefault('printer_font_scale', '1'),
        ) ??
        1;
    final protocol =
        await settings.getStringOrDefault('printer_protocol', 'tspl');
    if (protocol == PrinterProtocol.tspl.value) {
      return buildTsplReceipt(
        receipt,
        paperWidthMm: widthMm,
        horizontalOffsetDots: horizontalOffsetDots,
        contentWidthDots: contentWidthDots,
        logoWidthDots: logoWidthDots,
        fontScale: fontScale,
      );
    }
    return buildEscPosReceiptWithLogo(receipt, width: widthMm == 80 ? 42 : 32);
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
