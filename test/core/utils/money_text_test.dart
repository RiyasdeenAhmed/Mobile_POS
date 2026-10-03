import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/theme/money_text.dart';

void main() {
  test('formats minor units with the default Rs symbol', () {
    expect(MoneyFormat.format(12345), 'Rs123.45');
    expect(MoneyFormat.format(0), 'Rs0.00');
    expect(MoneyFormat.format(5), 'Rs0.05');
    expect(MoneyFormat.format(100), 'Rs1.00');
    expect(MoneyFormat.format(-250), '-Rs2.50');
  });

  test('supports an explicit symbol override', () {
    expect(MoneyFormat.format(12345, symbol: r'$'), r'$123.45');
    expect(MoneyFormat.parseMajorToMinor(r'$1,234.50', symbol: r'$'), 123450);
  });

  test('parses major amount strings to minor units', () {
    expect(MoneyFormat.parseMajorToMinor('123.45'), 12345);
    expect(MoneyFormat.parseMajorToMinor('123'), 12300);
    expect(MoneyFormat.parseMajorToMinor('0.5'), 50);
    expect(MoneyFormat.parseMajorToMinor('Rs1,234.50'), 123450);
  });

  test('default symbol is configurable at runtime', () {
    final original = MoneyFormat.defaultSymbol;
    addTearDown(() => MoneyFormat.defaultSymbol = original);
    MoneyFormat.defaultSymbol = 'LKR';
    expect(MoneyFormat.format(150), 'LKR1.50');
    expect(MoneyFormat.parseMajorToMinor('LKR1.50'), 150);
  });

  testWidgets('MoneyText renders formatted amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyText(amountMinor: 12345)),
      ),
    );
    expect(find.text('Rs123.45'), findsOneWidget);
  });
}
