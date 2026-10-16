enum TapToPayStatus {
  unavailable,
  starting,
  waitingForTap,
  approved,
  declined,
  cancelled,
  timedOut,
  failed,
}

class TapToPayResult {
  final TapToPayStatus status;
  final String? provider;
  final String? transactionReference;
  final String? message;

  const TapToPayResult({
    required this.status,
    this.provider,
    this.transactionReference,
    this.message,
  });

  bool get approved => status == TapToPayStatus.approved;
}

abstract interface class TapToPayService {
  bool get enabled;
  Future<TapToPayResult> collectPayment({required int amountMinor});
  Future<TapToPayResult> refund({
    required int amountMinor,
    required String transactionReference,
  });
}

class UnavailableTapToPayService implements TapToPayService {
  @override
  bool get enabled => false;

  @override
  Future<TapToPayResult> collectPayment({required int amountMinor}) async =>
      const TapToPayResult(
        status: TapToPayStatus.unavailable,
        message: 'Tap to pay is not configured',
      );

  @override
  Future<TapToPayResult> refund({
    required int amountMinor,
    required String transactionReference,
  }) async =>
      const TapToPayResult(
        status: TapToPayStatus.unavailable,
        message: 'Tap to pay is not configured',
      );
}

class MockTapToPayService implements TapToPayService {
  final TapToPayResult nextResult;
  const MockTapToPayService({this.nextResult = const TapToPayResult(
    status: TapToPayStatus.approved,
    provider: 'mock',
    transactionReference: 'mock-reference',
  )});

  @override
  bool get enabled => true;

  @override
  Future<TapToPayResult> collectPayment({required int amountMinor}) async =>
      nextResult;

  @override
  Future<TapToPayResult> refund({
    required int amountMinor,
    required String transactionReference,
  }) async =>
      nextResult;
}
