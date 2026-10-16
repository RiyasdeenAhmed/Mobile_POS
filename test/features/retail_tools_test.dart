import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'package:qubexcore_pos/core/platform/retail_files.dart';
import 'package:qubexcore_pos/features/invoices/data/invoice_destination.dart';
import 'package:qubexcore_pos/features/products/data/product_csv_service.dart';
import 'package:qubexcore_pos/features/products/data/product_repository.dart';
import 'package:qubexcore_pos/features/profit/data/profit_repository.dart';
import 'package:qubexcore_pos/features/expenses/data/expense_repository.dart';
import 'package:qubexcore_pos/features/staff/application/staff_session.dart';
import 'package:qubexcore_pos/features/staff/domain/staff_user.dart';
import 'package:qubexcore_pos/features/barcode/data/barcode_label_service.dart';
import 'package:qubexcore_pos/features/checkout/data/checkout_service.dart';
import 'package:qubexcore_pos/features/checkout/domain/checkout_models.dart';
import 'package:qubexcore_pos/features/pos/domain/cart_item.dart';
import 'package:qubexcore_pos/features/sales/data/return_service.dart';
import 'package:qubexcore_pos/features/sales/domain/sale_return.dart';
import 'package:qubexcore_pos/features/customers/data/customer_repository.dart';
import 'package:qubexcore_pos/features/customers/data/repayment_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeFiles extends RetailFiles {
  String? selected, destination;
  bool fail = false;
  @override
  Future<String?> chooseFolder() async => selected;
  @override
  Future<String?> save(
      {required String name,
      required List<int> bytes,
      String mime = 'application/pdf',
      String? folder}) async {
    destination = folder;
    if (fail) throw const FileSystemException('Access revoked');
    return selected;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late AppDatabase db;
  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
  });
  tearDown(() async {
    await db.close();
  });

  test('CSV handles BOM, quotes, line endings and leading zeros', () async {
    final service = ProductCsvService(db);
    final rows = await service.preview(
        '\uFEFFname,barcode,selling_price,category,opening_stock\r\n"Tea, green",00123,12.50,Drinks,3\r\n"A ""quoted"" item",00999,5.00,Drinks,0\r\n');
    expect(rows.every((r) => r.error == null), true);
    expect(await service.commit(rows), 2);
    final products = await db.db.query('products');
    expect(products.first['barcode'], '00123');
    expect(products.first['selling_price_minor'], 1250);
    expect((await db.db.query('categories')).length, 1);
    expect((await db.db.query('stock_movements')).single['quantity_change'], 3);
    expect(await service.commit(rows), 0);
  });
  test('CSV blocks invalid rows, flags repeats and skips existing matches',
      () async {
    final service = ProductCsvService(db);
    await ProductRepository(db).create(
        name: 'Existing', barcode: '001', sku: 'A', sellingPriceMinor: 100);
    final rows = await service.preview(
        'name,sku,barcode,selling_price\nExisting,A,001,2\nBad,B,002,1.234\nGood,C,003,3\nRepeat,C,004,4');
    expect(rows[0].duplicate, true);
    expect(rows[1].error, isNotNull);
    expect(rows[3].error, isNotNull);
    await expectLater(service.commit(rows), throwsStateError);
    rows[1].excluded = true;
    rows[3].excluded = true;
    expect(await service.commit(rows), 1);
    expect(
        (await db.db.query('products', where: 'sku=?', whereArgs: ['A']))
            .single['selling_price_minor'],
        100);
  });
  test('CSV rolls back products and categories when stock recording fails',
      () async {
    final service = ProductCsvService(db);
    final rows = await service
        .preview('name,selling_price,category,opening_stock\nTea,2,Drinks,3');
    await db.db.execute(
        "CREATE TRIGGER reject_stock BEFORE INSERT ON stock_movements BEGIN SELECT RAISE(ABORT,'test failure'); END");
    await expectLater(service.commit(rows), throwsA(anything));
    expect(await db.db.query('products'), isEmpty);
    expect(await db.db.query('categories'), isEmpty);
  });
  test(
      'profit excludes tax, respects discounts and historical cost, reverses returns',
      () async {
    final p = (await ProductRepository(db).create(
            name: 'Tea',
            costPriceMinor: 200,
            sellingPriceMinor: 1000,
            stockQuantity: 10))
        .dataOrNull!;
    await SettingsRepository(db).setString('tax_rate_bps', '1000');
    final result = await CheckoutService(db).completeSale(CheckoutRequest(
        items: [CartItem.fromProduct(p, quantity: 1.5, discountMinor: 100)],
        paymentMethod: 'cash',
        cashReceivedMinor: 2000));
    expect(result.isSuccess, true);
    final now = DateTime.now(), repo = ProfitRepository(db);
    final start = DateTime(now.year, now.month, now.day),
        end = DateTime(now.year, now.month, now.day + 1);
    var report = await repo.report(start, end);
    expect(report.revenueMinor, 1400);
    expect(report.costMinor, 300);
    expect(report.grossMinor, 1100);
    await ProductRepository(db).update(p.copyWith(costPriceMinor: 900));
    expect((await repo.report(start, end)).grossMinor, 1100);
    final item = (await db.db.query('sale_items')).single;
    final returned = await ReturnService(db).createReturn(
        saleId: result.dataOrNull!.sale.id!,
        lines: [ReturnLineInput(saleItemId: item['id'] as int, quantity: .5)]);
    expect(returned.isSuccess, true);
    report = await repo.report(start, end);
    expect(report.revenueMinor, 900);
    expect(report.costMinor, 200);
    expect(report.grossMinor, 700);
    expect(
        (await repo.report(end, DateTime(now.year, now.month, now.day + 2)))
            .netMinor,
        0);
  });
  test('credit profit is recognized once and repayments do not add revenue',
      () async {
    final p = (await ProductRepository(db).create(
            name: 'Tea',
            costPriceMinor: 200,
            sellingPriceMinor: 1000,
            stockQuantity: 10))
        .dataOrNull!;
    final c = (await CustomerRepository(db).create(
            name: 'Customer', creditLimitMinor: 10000, creditEnabled: true))
        .dataOrNull!;
    final result = await CheckoutService(db).completeSale(CheckoutRequest(
        items: [CartItem.fromProduct(p)],
        paymentMethod: 'credit',
        customerUuid: c.uuid));
    expect(result.isSuccess, true);
    final start = DateTime(2000),
        end = DateTime(2100),
        repo = ProfitRepository(db);
    expect((await repo.report(start, end)).grossMinor, 800);
    await RepaymentService(db)
        .recordRepayment(customerUuid: c.uuid, amountMinor: 500);
    expect((await repo.report(start, end)).grossMinor, 800);
  });
  test('expenses require admin and correction preserves audit history',
      () async {
    final session = StaffSession();
    final repo = ExpenseRepository(db, session);
    await expectLater(
        repo.add(amount: 100, category: 'Rent', date: DateTime.now()),
        throwsStateError);
    session.adopt(const StaffUser(
        uuid: 'admin',
        username: 'admin',
        displayName: 'Admin',
        role: 'admin',
        createdAt: '',
        updatedAt: ''));
    final now = DateTime.now();
    await repo.add(amount: 100, category: 'Rent', date: now);
    final first = (await repo.list()).single;
    await repo.add(
        amount: 150, category: 'Rent', date: now, replaces: first['id'] as int);
    final all = await repo.list();
    expect(all.length, 2);
    expect(all.where((r) => r['voided_at'] != null).length, 1);
    final report = await ProfitRepository(db).report(
        DateTime(now.year, now.month), DateTime(now.year, now.month + 1));
    expect(report.expensesMinor, 150);
    expect(report.netMinor, -150);
    await expectLater(
        repo.voidEntry(first['id'] as int, 'again'), throwsStateError);
    session.dispose();
  });
  test('barcode generation is stable, unique and exports a PDF', () async {
    final repo = ProductRepository(db), service = BarcodeLabelService(db);
    final p =
        (await repo.create(name: 'Tea', sellingPriceMinor: 100)).dataOrNull!;
    final q = (await repo.create(
            name: 'Coffee', barcode: '001234', sellingPriceMinor: 200))
        .dataOrNull!;
    final code = await service.ensureBarcode(p.uuid);
    expect(await service.ensureBarcode(p.uuid), code);
    expect(await service.ensureBarcode(q.uuid), '001234');
    final updated = await repo.findByUuid(p.uuid);
    final bytes = await service.pdf(updated!,
        width: 50, height: 30, copies: 2, price: true);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(() => BarcodeLabelService.validate(code, 10, 30, 1),
        throwsArgumentError);
  });
  test('invoice folder persists, Save As bypasses it and cancellation is quiet',
      () async {
    final files = FakeFiles()..selected = 'content://folder';
    final service = InvoiceDestination(SettingsRepository(db), files);
    await service.choose();
    expect(await service.folder, 'content://folder');
    files.selected = null;
    expect(await service.save('INV.pdf', [1]), isNull);
    expect(files.destination, 'content://folder');
    await service.save('INV.pdf', [1], saveAs: true);
    expect(files.destination, isNull);
    files.fail = true;
    await expectLater(
        service.save('INV.pdf', [1]), throwsA(isA<FileSystemException>()));
    await service.reset();
    expect(await service.folder, isNull);
  });
  test('desktop default-folder exports preserve colliding invoices', () async {
    final dir = await Directory.systemTemp.createTemp('qubex_exports_');
    try {
      final files = RetailFiles();
      final a = await files.save(name: 'INV.pdf', bytes: [1], folder: dir.path);
      final b = await files.save(name: 'INV.pdf', bytes: [2], folder: dir.path);
      expect(a, isNot(b));
      expect(await File(a!).readAsBytes(), [1]);
      expect(await File(b!).readAsBytes(), [2]);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
