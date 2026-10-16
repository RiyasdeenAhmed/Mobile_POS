import '../../payments/domain/payment.dart';
import '../../pos/domain/cart_item.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';

class PaymentAllocation {
  final String method;
  final int amountMinor;
  final int? receivedMinor;
  final String? reference;
  const PaymentAllocation(
      {required this.method,
      required this.amountMinor,
      this.receivedMinor,
      this.reference});
}

class CheckoutRequest {
  final List<CartItem> items;
  final List<PaymentAllocation> allocations;
  final String paymentMethod;
  final int cashReceivedMinor;
  final String? cardReference;
  final String? customerUuid;
  final String? staffUuid;
  final String? notes;
  final String? saleUuid;

  const CheckoutRequest({
    required this.items,
    this.allocations = const [],
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
  final List<Payment> payments;
  Payment get payment => payments.first;
  final int changeMinor;

  const CheckoutOutcome({
    required this.sale,
    required this.items,
    required this.payments,
    required this.changeMinor,
  });
}
