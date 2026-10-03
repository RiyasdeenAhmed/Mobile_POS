import '../../payments/domain/payment.dart';
import '../../pos/domain/cart_item.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';

class CheckoutRequest {
  final List<CartItem> items;
  final String paymentMethod;
  final int cashReceivedMinor;
  final String? cardReference;
  final String? customerUuid;
  final String? staffUuid;
  final String? notes;
  final String? saleUuid;

  const CheckoutRequest({
    required this.items,
    this.paymentMethod = PaymentMethods.cash,
    this.cashReceivedMinor = 0,
    this.cardReference,
    this.customerUuid,
    this.staffUuid,
    this.notes,
    this.saleUuid,
  });
}

class CheckoutOutcome {
  final Sale sale;
  final List<SaleItem> items;
  final Payment payment;
  final int changeMinor;

  const CheckoutOutcome({
    required this.sale,
    required this.items,
    required this.payment,
    required this.changeMinor,
  });
}
