import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/widgets/stock_status.dart';

void main() {
  StockStatus resolve({
    required bool trackStock,
    required double stock,
    required double reorderLevel,
  }) {
    return resolveStockStatus(
      trackStock: trackStock,
      stock: stock,
      reorderLevel: reorderLevel,
    );
  }

  group('resolveStockStatus', () {
    test('untracked products never count as low or out', () {
      expect(
        resolve(trackStock: false, stock: 0, reorderLevel: 0),
        StockStatus.notTracked,
      );
      expect(
        resolve(trackStock: false, stock: 40, reorderLevel: 10),
        StockStatus.notTracked,
      );
    });

    test('zero or negative stock is out of stock', () {
      expect(
        resolve(trackStock: true, stock: 0, reorderLevel: 5),
        StockStatus.out,
      );
      expect(
        resolve(trackStock: true, stock: -3, reorderLevel: 0),
        StockStatus.out,
      );
    });

    test('stock at or below the reorder level is low', () {
      expect(
        resolve(trackStock: true, stock: 5, reorderLevel: 5),
        StockStatus.low,
      );
      expect(
        resolve(trackStock: true, stock: 2, reorderLevel: 5),
        StockStatus.low,
      );
    });

    test('stock above the reorder level is in stock', () {
      expect(
        resolve(trackStock: true, stock: 6, reorderLevel: 5),
        StockStatus.inStock,
      );
      expect(
        resolve(trackStock: true, stock: 5, reorderLevel: 0),
        StockStatus.inStock,
      );
    });
  });

  testWidgets('badge renders the shared labels and light-red low design',
      (tester) async {
    const light = MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            StockStatusBadge(status: StockStatus.inStock),
            StockStatusBadge(status: StockStatus.low),
            StockStatusBadge(status: StockStatus.out),
            StockStatusBadge(status: StockStatus.notTracked),
          ],
        ),
      ),
    );
    await tester.pumpWidget(light);

    expect(find.text('In Stock'), findsOneWidget);
    expect(find.text('Low Stock'), findsOneWidget);
    expect(find.text('Out of Stock'), findsOneWidget);
    expect(find.text('Not Tracked'), findsOneWidget);

    final lowText = tester.widget<Text>(find.text('Low Stock'));
    expect(lowText.style?.color, const Color(0xFFC62828));

    final outText = tester.widget<Text>(find.text('Out of Stock'));
    expect(outText.style?.color, Colors.white);

    final lowBox = tester.widget<Container>(
      find.ancestor(
        of: find.text('Low Stock'),
        matching: find.byType(Container),
      ),
    );
    final lowDecoration = lowBox.decoration! as BoxDecoration;
    expect(lowDecoration.color, const Color(0xFFFDECEC));
  });
}
