import '../../sales/data/sale_repository.dart';
import '../../payments/domain/payment.dart';
import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../../core/database/settings_repository.dart';
import '../../customers/data/customer_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../domain/invoice_document.dart';

/// Contract for producing, storing, and sharing invoice PDFs.
///
/// [buildDocument]/[render] are pure; [save]/[share] touch the platform.
/// Printer/share failures must never affect an already completed sale.
abstract class InvoicePdfService {
  Future<pw.Document> buildDocument({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  });

  Future<List<int>> render({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  });

  Future<File> save(
    Directory directory, {
    required String fileName,
    required List<int> bytes,
  });

  Future<void> share(File file);
}

class DefaultInvoicePdfService implements InvoicePdfService {
  DefaultInvoicePdfService({
    required this.settings,
    required this.customers,
  });

  final SettingsRepository settings;
  final CustomerRepository customers;

  @override
  Future<pw.Document> buildDocument({
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
    return InvoiceDocument(
      payments: payments,
      sale: sale,
      items: items,
      settings: map,
      customerName: customerName,
      cashierName: cashierName,
    ).build();
  }

  @override
  Future<List<int>> render({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    final document = await buildDocument(
      sale: sale,
      items: items,
      cashierName: cashierName,
    );
    return document.save();
  }

  @override
  Future<File> save(
    Directory directory, {
    required String fileName,
    required List<int> bytes,
  }) async {
    await directory.create(recursive: true);
    final file = File(p.normalize(p.join(directory.path, fileName)));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<void> share(File file) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        title: p.basenameWithoutExtension(file.path),
      ),
    );
  }
}
