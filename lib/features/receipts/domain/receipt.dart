import '../../payments/domain/payment.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import 'package:intl/intl.dart';

class ReceiptLine {
  final String productName;
  final String? barcode;
  final double quantity;
  final int unitPriceMinor;
  final int discountMinor;
  final int lineTotalMinor;

  const ReceiptLine({
    required this.productName,
    this.barcode,
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
  final List<Payment> payments;
  final String storeName;
  final String storeAddress;
  final String storePhone;
  final String branchName;
  final String hotline;
  final String terminalNumber;
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
  final String? logoPath;

  const Receipt({
    this.payments = const [],
    required this.storeName,
    required this.storeAddress,
    required this.storePhone,
    this.branchName = '',
    this.hotline = '',
    this.terminalNumber = '',
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
    this.logoPath,
  });

  /// Printer friendly local date. The app currently follows the device
  /// timezone, which is the configured business timezone for offline use.
  String get formattedDate {
    final parsed = DateTime.tryParse(saleAt);
    return parsed == null
        ? saleAt
        : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  String get formattedTime {
    final parsed = DateTime.tryParse(saleAt);
    return parsed == null ? '' : DateFormat('hh:mm a').format(parsed.toLocal());
  }

  /// Builds a receipt from a committed sale, its snapshot items, and the
  /// settings map from [SettingsRepository.loadCoreSettings].
  factory Receipt.fromSale({
    required Sale sale,
    List<Payment> payments = const [],
    required List<SaleItem> items,
    required Map<String, String> settings,
    String? cashierName,
    String? customerName,
  }) {
    return Receipt(
      payments: payments,
      storeName: _nonEmpty(settings['store_name']) ?? 'QubeXCore Store',
      storeAddress: settings['store_address'] ?? '',
      storePhone: settings['store_phone'] ?? '',
      branchName: settings['branch_name'] ?? '',
      hotline: settings['hotline'] ?? '',
      terminalNumber: settings['terminal_number'] ?? '',
      invoiceNumber: sale.invoiceNumber,
      saleAt: sale.saleAt,
      cashierName: cashierName,
      customerName: customerName,
      lines: items
          .map(
            (item) => ReceiptLine(
              productName: item.productName,
              barcode: item.productBarcode,
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
      logoPath: _nonEmpty(settings['business_logo_path']),
    );
  }

  static String? _nonEmpty(String? value) =>
      value == null || value.trim().isEmpty ? null : value;
}
