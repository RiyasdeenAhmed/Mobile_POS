import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/invoices/data/invoice_pdf_service.dart';
import 'package:qubexcore_pos/features/sales/data/sale_repository.dart';
import 'package:qubexcore_pos/features/sales/domain/sale.dart';
import 'package:qubexcore_pos/features/sales/domain/sale_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late AppDatabase db;
  late SaleRepository sales;
  late DefaultInvoicePdfService service;
  late Sale sale;
  late List<SaleItem> items;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    sales = SaleRepository(db);
    service = DefaultInvoicePdfService(
      settings: SettingsRepository(db),
      customers: CustomerRepository(db),
    );

    final now = DateTime.now().toUtc().toIso8601String();
    final productId = await db.db.insert('products', <String, Object?>{
      'uuid': 'prod-inv-1',
      'name': 'Espresso',
      'cost_price_minor': 500,
      'selling_price_minor': 1200,
      'currency': 'LKR',
      'stock_quantity': 8.0,
      'reorder_level': 2.0,
      'track_stock': 1,
      'created_at': now,
      'updated_at': now,
    });
    final saleId = await db.db.insert('sales', <String, Object?>{
      'uuid': 'sale-inv-1',
      'invoice_number': 'INV-0001',
      'sale_at': now,
      'subtotal_minor': 2400,
      'total_minor': 2400,
      'amount_paid_minor': 2400,
      'status': 'completed',
      'payment_method': 'cash',
      'created_at': now,
      'updated_at': now,
    });
    await db.db.insert('sale_items', <String, Object?>{
      'uuid': 'item-inv-1',
      'sale_id': saleId,
      'product_id': productId,
      'product_uuid': 'prod-inv-1',
      'product_name': 'Espresso',
      'quantity': 2.0,
      'unit_price_minor': 1200,
      'line_total_minor': 2400,
      'created_at': now,
    });
    sale = (await sales.findByUuid('sale-inv-1'))!;
    items = await sales.listItems(saleId);
  });

  tearDown(() async {
    await db.close();
  });

  test('render returns a valid PDF and never touches the sale rows', () async {
    final saleBefore = await db.db.query(
      'sales',
      where: 'uuid = ?',
      whereArgs: ['sale-inv-1'],
    );
    final itemsBefore = await db.db.query('sale_items');

    final bytes = await service.render(
      sale: sale,
      items: items,
      cashierName: 'Ash',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');

    // Financial history is byte-identical before and after invoice work.
    final saleAfter = await db.db.query(
      'sales',
      where: 'uuid = ?',
      whereArgs: ['sale-inv-1'],
    );
    final itemsAfter = await db.db.query('sale_items');
    expect(saleAfter, saleBefore);
    expect(itemsAfter, itemsBefore);
  });

  test('save writes the exact rendered bytes under the invoice file name',
      () async {
    final bytes = await service.render(
      sale: sale,
      items: items,
      cashierName: null,
    );
    final dir = await Directory.systemTemp.createTemp('qubex_invoice_test');
    addTearDown(() => dir.delete(recursive: true));

    final file = await service.save(
      Directory('${dir.path}/invoices'),
      fileName: '${sale.invoiceNumber}.pdf',
      bytes: bytes,
    );

    expect(
        file.path,
        endsWith('${Platform.pathSeparator}invoices'
            '${Platform.pathSeparator}INV-0001.pdf'));
    expect(await file.readAsBytes(), equals(bytes));
  });
}
