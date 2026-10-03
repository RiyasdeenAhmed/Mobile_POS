import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/receipts/data/escpos_builder.dart';
import 'package:qubexcore_pos/features/receipts/data/mock_printer.dart';
import 'package:qubexcore_pos/features/receipts/data/printer_service.dart';
import 'package:qubexcore_pos/features/receipts/data/receipt_print_service.dart';
import 'package:qubexcore_pos/features/receipts/domain/receipt.dart';
import 'package:qubexcore_pos/features/sales/domain/sale.dart';
import 'package:qubexcore_pos/features/sales/domain/sale_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Sale makeSale() => const Sale(
      uuid: 'sale-1',
      invoiceNumber: 'INV-0001',
      saleAt: '2026-01-05T10:00:00Z',
      subtotalMinor: 1200,
      discountMinor: 100,
      taxMinor: 50,
      totalMinor: 1150,
      amountPaidMinor: 2000,
      changeMinor: 850,
      amountDueMinor: 0,
      paymentMethod: 'cash',
      createdAt: '2026-01-05T10:00:00Z',
      updatedAt: '2026-01-05T10:00:00Z',
    );

List<SaleItem> makeItems() => const [
      SaleItem(
        uuid: 'item-1',
        saleId: 1,
        productId: 1,
        productUuid: 'prod-1',
        productName: 'Espresso',
        quantity: 2,
        unitPriceMinor: 600,
        discountMinor: 100,
        lineTotalMinor: 1100,
        createdAt: '2026-01-05T10:00:00Z',
      ),
    ];

Map<String, String> testSettings() => <String, String>{
      'store_name': 'Corner Kade',
      'store_address': '12 Main Street',
      'store_phone': '0771234567',
      'currency_symbol': 'Rs',
      'receipt_footer': 'Come again!',
    };

void main() {
  group('formatAmount', () {
    test('formats minor units with two decimals', () {
      expect(formatAmount(0), '0.00');
      expect(formatAmount(300), '3.00');
      expect(formatAmount(1150), '11.50');
      expect(formatAmount(5), '0.05');
      expect(formatAmount(-50), '-0.50');
    });
  });

  group('EscPosBuilder', () {
    test('init, padded line, feed and cut produce expected bytes', () {
      final builder = EscPosBuilder(width: 8)..init();
      builder.line('AB', '12');
      final bytes = builder.build();

      expect(bytes.sublist(0, 2), EscPosBuilder.initSequence);
      expect(bytes.sublist(2, 11), <int>[...utf8.encode('AB    12'), 0x0A]);
      expect(bytes.sublist(bytes.length - 7, bytes.length - 4), <int>[
        0x1B,
        0x64,
        4,
      ]);
      expect(bytes.sublist(bytes.length - 4), EscPosBuilder.cutSequence);
    });

    test('overlong left text is truncated so the line fits', () {
      final builder = EscPosBuilder(width: 6)..init();
      builder.line('ABCDEFGH', '12');
      final bytes = builder.build();
      final text = utf8.decode(
        bytes.sublist(2, bytes.length - 7),
        allowMalformed: true,
      );
      expect(text, 'ABCD12\n');
    });

    test('buildEscPosReceipt renders store, invoice, totals, and footer', () {
      final receipt = Receipt.fromSale(
        sale: makeSale(),
        items: makeItems(),
        settings: testSettings(),
        cashierName: 'Amal',
        customerName: 'Nimal',
      );
      final bytes = buildEscPosReceipt(receipt, width: 32);
      final text = utf8.decode(bytes, allowMalformed: true);

      expect(bytes.sublist(0, 2), EscPosBuilder.initSequence);
      expect(bytes.sublist(bytes.length - 4), EscPosBuilder.cutSequence);
      expect(text, contains('Corner Kade'));
      expect(text, contains('12 Main Street'));
      expect(text, contains('INV-0001'));
      expect(text, contains('Cashier: Amal'));
      expect(text, contains('Customer: Nimal'));
      expect(text, contains('2 x Espresso'));
      expect(text, contains('Rs 11.00'));
      expect(text, contains('Rs 11.50'));
      expect(text, contains('CASH'));
      expect(text, contains('Come again!'));
    });
  });

  group('Receipt.fromSale', () {
    test('maps sale, items, and settings', () {
      final receipt = Receipt.fromSale(
        sale: makeSale(),
        items: makeItems(),
        settings: testSettings(),
        cashierName: 'Amal',
        customerName: 'Nimal',
      );

      expect(receipt.storeName, 'Corner Kade');
      expect(receipt.currencySymbol, 'Rs');
      expect(receipt.footer, 'Come again!');
      expect(receipt.invoiceNumber, 'INV-0001');
      expect(receipt.cashierName, 'Amal');
      expect(receipt.customerName, 'Nimal');
      expect(receipt.totalMinor, 1150);
      expect(receipt.lines, hasLength(1));
      expect(receipt.lines.single.productName, 'Espresso');
      expect(receipt.lines.single.quantityText, '2');
      expect(receipt.lines.single.unitPriceMinor, 600);
    });

    test('falls back to defaults when settings are empty', () {
      final receipt = Receipt.fromSale(
        sale: makeSale(),
        items: makeItems(),
        settings: const {},
      );

      expect(receipt.storeName, 'QubeXCore Store');
      expect(receipt.currencySymbol, 'Rs');
      expect(receipt.cashierName, isNull);
      expect(receipt.customerName, isNull);
    });
  });

  group('ReceiptPrintService', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    late AppDatabase db;
    late SettingsRepository settings;
    late CustomerRepository customers;

    setUp(() async {
      db = await AppDatabase.open(path: inMemoryDatabasePath);
      settings = SettingsRepository(db);
      customers = CustomerRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('printSale sends ESC/POS bytes to the printer', () async {
      final printer = MockPrinter();
      final service = ReceiptPrintService(
        printer: printer,
        settings: settings,
        customers: customers,
      );

      await service.printSale(sale: makeSale(), items: makeItems());

      expect(printer.jobs, hasLength(1));
      final text = utf8.decode(printer.jobs.single, allowMalformed: true);
      expect(text, contains('INV-0001'));
    });

    test('printSale surfaces printer failure as PrinterException', () async {
      final printer = MockPrinter(fail: true);
      final service = ReceiptPrintService(
        printer: printer,
        settings: settings,
        customers: customers,
      );

      expect(
        () => service.printSale(sale: makeSale(), items: makeItems()),
        throwsA(isA<PrinterException>()),
      );
      expect(printer.jobs, isEmpty);
    });

    test('autoPrintEnabled follows the auto_print_receipt setting', () async {
      final service = ReceiptPrintService(
        printer: MockPrinter(),
        settings: settings,
        customers: customers,
      );

      expect(await service.autoPrintEnabled(), isFalse);
      await settings.setString('auto_print_receipt', '1');
      expect(await service.autoPrintEnabled(), isTrue);
    });
  });
}
