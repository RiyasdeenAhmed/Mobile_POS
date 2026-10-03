import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';

class ReceiptLine {
  final String productName;
  final double quantity;
  final int unitPriceMinor;
  final int discountMinor;
  final int lineTotalMinor;

  const ReceiptLine({
    required this.productName,
    required this.quantity,
    required this.unitPriceMinor,
    required this.discountMinor,
    required this.lineTotalMinor,
  });

  String get quantityText => quantity == quantity.roundToDouble()
      ? quantity.round().toString()
      : quantity.toString();
}

class Receipt {
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String invoiceNumber;
  final String saleAt;
  final String? cashierName;
  final String? customerName;
  final List<ReceiptLine> lines;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
  final String paymentMethod;
  final int amountPaidMinor;
  final int changeMinor;
  final int amountDueMinor;
  final String currencySymbol;
  final String footer;

  const Receipt({
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    required this.invoiceNumber,
    required this.saleAt,
    required this.cashierName,
    required this.customerName,
    required this.lines,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
    required this.paymentMethod,
    required this.amountPaidMinor,
    required this.changeMinor,
    required this.amountDueMinor,
    required this.currencySymbol,
    required this.footer,
  });

  /// Builds a receipt from a committed sale, its snapshot items, and the
  /// settings map from [SettingsRepository.loadCoreSettings].
  factory Receipt.fromSale({
    required Sale sale,
    required List<SaleItem> items,
    required Map<String, String> settings,
    String? cashierName,
    String? customerName,
  }) {
    return Receipt(
      storeName: _nonEmpty(settings['store_name']) ?? 'QubeXCore Store',
      storeAddress: settings['store_address'] ?? '',
      storePhone: settings['store_phone'] ?? '',
      invoiceNumber: sale.invoiceNumber,
      saleAt: sale.saleAt,
      cashierName: cashierName,
      customerName: customerName,
      lines: items
          .map(
            (item) => ReceiptLine(
              productName: item.productName,
              quantity: item.quantity,
              unitPriceMinor: item.unitPriceMinor,
              discountMinor: item.discountMinor,
              lineTotalMinor: item.lineTotalMinor,
            ),
          )
          .toList(growable: false),
      subtotalMinor: sale.subtotalMinor,
      discountMinor: sale.discountMinor,
      taxMinor: sale.taxMinor,
      totalMinor: sale.totalMinor,
      paymentMethod: sale.paymentMethod,
      amountPaidMinor: sale.amountPaidMinor,
      changeMinor: sale.changeMinor,
      amountDueMinor: sale.amountDueMinor,
      currencySymbol: _nonEmpty(settings['currency_symbol']) ?? 'Rs',
      footer: settings['receipt_footer'] ?? '',
    );
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
