import 'package:qubexcore_pos/core/database/settings_repository.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nested/nested.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qubexcore_pos/app/providers.dart';
import 'package:qubexcore_pos/app/routes.dart';
import 'package:qubexcore_pos/core/database/app_database.dart';
import 'package:qubexcore_pos/core/theme/app_theme.dart';
import 'package:qubexcore_pos/features/invoices/data/invoice_pdf_service.dart';
import 'package:qubexcore_pos/features/sales/domain/sale.dart';
import 'package:qubexcore_pos/features/sales/domain/sale_item.dart';
import 'package:qubexcore_pos/features/sales/presentation/sale_detail_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

class _FakeInvoicePdfService implements InvoicePdfService {
  _FakeInvoicePdfService(this.root);
  final String root;
  int renderCalls = 0;
  File? sharedFile;

  @override
  Future<pw.Document> buildDocument({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    throw UnimplementedError('not needed in the widget test');
  }

  @override
  Future<List<int>> render({
    required Sale sale,
    required List<SaleItem> items,
    String? cashierName,
  }) async {
    renderCalls++;
    return <int>[0x25, 0x50, 0x44, 0x46]; // %PDF
  }

  @override
  Future<File> save(
    Directory directory, {
    required String fileName,
    required List<int> bytes,
  }) async {
    await directory.create(recursive: true);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Future<void> share(File file) async {
    sharedFile = file;
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<T> realAsync<T>(WidgetTester tester, Future<T> Function() body) async {
    late T result;
    await tester.runAsync(() async => result = await body());
    return result;
  }

  late AppDatabase db;
  late _FakeInvoicePdfService fakeService;
  late Directory tempRoot;

  setUp(() async {
    db = await AppDatabase.open(path: inMemoryDatabasePath);
    tempRoot = await Directory.systemTemp.createTemp('qubex_sale_detail');
    PathProviderPlatform.instance = _FakePathProvider(tempRoot.path);
    fakeService = _FakeInvoicePdfService(tempRoot.path);
    final destination = await Directory('${tempRoot.path}/invoices').create();
    await SettingsRepository(db)
        .setString('invoice_folder_uri', destination.path);

    final now = DateTime.now().toUtc().toIso8601String();
    final productId = await db.db.insert('products', <String, Object?>{
      'uuid': 'prod-actions-1',
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
      'uuid': 'sale-actions-1',
      'invoice_number': 'INV-0042',
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
      'uuid': 'item-actions-1',
      'sale_id': saleId,
      'product_id': productId,
      'product_uuid': 'prod-actions-1',
      'product_name': 'Espresso',
      'quantity': 2.0,
      'unit_price_minor': 1200,
      'line_total_minor': 2400,
      'created_at': now,
    });
  });

  tearDown(() async {
    await db.close();
    await tempRoot.delete(recursive: true);
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final List<SingleChildWidget> providers = buildAppProviders(db);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ...providers,
            Provider<InvoicePdfService>.value(value: fakeService),
          ],
          child: MaterialApp(
            theme: QubeXCoreTheme.light(),
            onGenerateRoute: AppRouter.onGenerateRoute,
            home: const SaleDetailScreen(saleUuid: 'sale-actions-1'),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();
  }

  testWidgets(
    'download saves the invoice PDF and leaves the sale rows untouched',
    (tester) async {
      final saleBefore = await realAsync(
        tester,
        () => db.db.query(
          'sales',
          where: 'uuid = ?',
          whereArgs: ['sale-actions-1'],
        ),
      );
      final itemsBefore = await realAsync(
        tester,
        () => db.db.query('sale_items'),
      );

      await pumpDetail(tester);
      expect(find.text('Print Receipt'), findsOneWidget);
      expect(find.text('Save Invoice'), findsOneWidget);
      expect(find.text('Share Invoice'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.text('Save Invoice'));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await tester.pumpAndSettle();

      expect(fakeService.renderCalls, 1);
      expect(find.textContaining('Invoice saved to'), findsOneWidget);

      final saved = File(
        '${tempRoot.path}${Platform.pathSeparator}invoices'
        '${Platform.pathSeparator}INV-0042.pdf',
      );
      expect(
        await realAsync(tester, () async => saved.readAsBytesSync()),
        equals(<int>[0x25, 0x50, 0x44, 0x46]),
      );

      final saleAfter = await realAsync(
        tester,
        () => db.db.query(
          'sales',
          where: 'uuid = ?',
          whereArgs: ['sale-actions-1'],
        ),
      );
      final itemsAfter = await realAsync(
        tester,
        () => db.db.query('sale_items'),
      );
      expect(saleAfter, saleBefore);
      expect(itemsAfter, itemsBefore);
    },
  );

  testWidgets('share sends the rendered invoice file', (tester) async {
    await pumpDetail(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Share Invoice'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
    });
    await tester.pumpAndSettle();

    expect(fakeService.sharedFile, isNotNull);
    expect(fakeService.sharedFile!.path, endsWith('INV-0042.pdf'));
    expect(find.textContaining('Sharing INV-0042'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
