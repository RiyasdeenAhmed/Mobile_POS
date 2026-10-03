import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/theme/money_text.dart';

void main() {
  test('formats minor units as currency', () {
    expect(MoneyFormat.format(12345), r'$123.45');
    expect(MoneyFormat.format(0), r'$0.00');
    expect(MoneyFormat.format(5), r'$0.05');
    expect(MoneyFormat.format(100), r'$1.00');
  });

  test('parses major amount strings to minor units', () {
    expect(MoneyFormat.parseMajorToMinor('123.45'), 12345);
    expect(MoneyFormat.parseMajorToMinor('123'), 12300);
    expect(MoneyFormat.parseMajorToMinor('0.5'), 50);
    expect(MoneyFormat.parseMajorToMinor(r'$1,234.50'), 123450);
  });

  testWidgets('MoneyText renders formatted amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyText(amountMinor: 12345)),
      ),
    );
    expect(find.text(r'$123.45'), findsOneWidget);
  });
}
