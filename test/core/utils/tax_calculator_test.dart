import 'package:flutter_test/flutter_test.dart';
import 'package:qubexcore_pos/core/utils/tax_calculator.dart';

void main() {
  test('computes basis-point tax', () {
    expect(TaxCalculator.taxMinor(1000, 1800), 180);
    expect(TaxCalculator.taxMinor(12345, 800), 988);
  });

  test('rounds half-up', () {
    expect(TaxCalculator.taxMinor(3333, 500), 167);
    expect(TaxCalculator.taxMinor(100, 500), 5);
    expect(TaxCalculator.taxMinor(101, 500), 5);
  });

  test('zero rate, zero or negative taxable returns zero', () {
    expect(TaxCalculator.taxMinor(1000, 0), 0);
    expect(TaxCalculator.taxMinor(1000, -100), 0);
    expect(TaxCalculator.taxMinor(0, 1800), 0);
    expect(TaxCalculator.taxMinor(-500, 1800), 0);
  });
}
