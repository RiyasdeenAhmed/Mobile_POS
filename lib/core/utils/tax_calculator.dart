abstract final class TaxCalculator {
  /// Computes tax in minor units from a taxable amount in minor units and a
  /// rate in basis points (18% = 1800 bps), rounding half-up.
  static int taxMinor(int taxableMinor, int rateBps) {
    if (taxableMinor <= 0 || rateBps <= 0) return 0;
    return (taxableMinor * rateBps + 5000) ~/ 10000;
  }
}
