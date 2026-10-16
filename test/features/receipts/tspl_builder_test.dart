import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/features/receipts/data/tspl_builder.dart';
import 'package:qubexcore_pos/features/receipts/domain/receipt.dart';

void main() {
  const receipt = Receipt(
    storeName: 'QubeX Store',
    storeAddress: 'Main Street',
    storePhone: '011 000 0000',
    invoiceNumber: 'INV-001',
    saleAt: '2026-10-14T12:00:00Z',
    cashierName: 'Cashier',
    customerName: 'Customer',
    lines: [
      ReceiptLine(
        productName: 'Long product name',
        quantity: 2,
        unitPriceMinor: 1250,
        discountMinor: 0,
        lineTotalMinor: 2500,
      ),
    ],
    subtotalMinor: 2500,
    discountMinor: 0,
    taxMinor: 0,
    totalMinor: 2500,
    paymentMethod: 'cash',
    amountPaidMinor: 3000,
    changeMinor: 500,
    amountDueMinor: 0,
    currencySymbol: 'Rs',
    footer: 'Thank you',
  );

  test('renders a 58 mm TSPL receipt with dynamic height', () {
    final output = String.fromCharCodes(
      buildTsplReceipt(receipt, paperWidthMm: 58),
    );

    expect(output, contains('SIZE 58 mm,'));
    expect(output, contains('QubeX Store'));
    expect(output, contains('TOTAL'));
    expect(output, isNot(contains('Paid')));
    expect(output, contains('Cash received'));
    expect(output, contains('PRINT 1,1'));
  });

  test('renders an 80 mm TSPL receipt with the wider layout', () {
    final output = String.fromCharCodes(
      buildTsplReceipt(receipt, paperWidthMm: 80),
    );

    expect(output, contains('SIZE 80 mm,'));
    expect(output, contains('Rs 25.00'));
    expect(output, contains('PRINT 1,1'));
  });

  test('escapes quotes in TSPL text', () {
    const quoted = Receipt(
      storeName: 'Store "A"',
      storeAddress: '',
      storePhone: '',
      invoiceNumber: 'INV-002',
      saleAt: '2026-10-14T12:00:00Z',
      cashierName: null,
      customerName: null,
      lines: [],
      subtotalMinor: 0,
      discountMinor: 0,
      taxMinor: 0,
      totalMinor: 0,
      paymentMethod: 'cash',
      amountPaidMinor: 0,
      changeMinor: 0,
      amountDueMinor: 0,
      currencySymbol: 'Rs',
      footer: '',
    );
    final output = String.fromCharCodes(
      buildTsplReceipt(quoted, paperWidthMm: 58),
    );
    expect(output, contains(r'Store \"A\"'));
  });
}
