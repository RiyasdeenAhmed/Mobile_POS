import '../../../core/utils/decimal_input.dart';
import '../../../core/database/settings_repository.dart';
import '../../../core/utils/id_generator.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/app_snack.dart';
import '../../checkout/domain/checkout_models.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../payments/domain/payment.dart';
import '../../pos/domain/cart_controller.dart';
import '../../receipts/data/receipt_print_service.dart';
import '../../staff/application/staff_session.dart';
import '../data/checkout_service.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = PaymentMethods.cash;
  final _cashController = TextEditingController();
  final _cardReferenceController = TextEditingController();
  Customer? _selectedCustomer;
  bool _submitting = false;
  bool _completed = false;
  final String _saleUuid = newBusinessId();
  bool _settingsLoaded = false;
  final _splitControllers = {
    for (final method in PaymentMethods.paid) method: TextEditingController()
  };
  final _splitReferences = {
    for (final method in PaymentMethods.paid) method: TextEditingController()
  };
  int _money(String value) {
    if (value.trim().isEmpty) return 0;
    try {
      return parseMoneyInput(value);
    } on FormatException {
      return -1;
    }
  }

  int get _total => context.read<CartController>().totalMinor;
  int get _cashAllocation => _paymentMethod == PaymentMethods.split
      ? _money(_splitControllers[PaymentMethods.cash]!.text)
      : _total;
  List<PaymentAllocation> get _allocations => [
        for (final entry in _splitControllers.entries)
          if (_money(entry.value.text) > 0)
            PaymentAllocation(
                method: entry.key,
                amountMinor: _money(entry.value.text),
                receivedMinor: entry.key == PaymentMethods.cash
                    ? _cashReceivedMinor
                    : null,
                reference: _splitReferences[entry.key]!.text)
      ];
  Future<void> _loadSettings() async {
    try {
      final value = await context
          .read<SettingsRepository>()
          .getStringOrDefault('tax_rate_bps', '0');
      if (mounted) {
        context.read<CartController>().setTaxRate(int.tryParse(value) ?? 0);
        setState(() {
          _settingsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Unable to load checkout settings',
            kind: AppSnackKind.error);
      }
    }
  }

  bool _customerLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
    });
  }

  @override
  void dispose() {
    for (final c in [..._splitControllers.values, ..._splitReferences.values]) {
      c.dispose();
    }
    _cashController.dispose();
    _cardReferenceController.dispose();
    super.dispose();
  }

  static const Object _walkInChoice = Object();

  Future<void> _pickCustomer() async {
    setState(() => _customerLoading = true);
    final repository = context.read<CustomerRepository>();
    List<Customer> customers;
    try {
      customers = await repository.list();
    } catch (_) {
      if (mounted) {
        setState(() => _customerLoading = false);
        showAppSnack(context, 'Unable to load customers',
            kind: AppSnackKind.error);
      }
      return;
    }
    if (!mounted) return;
    setState(() => _customerLoading = false);

    // Credit sales may only go to customers whose credit facility is on and
    // funded; cash and card sales can attach any active customer.
    final selectable = _paymentMethod == PaymentMethods.credit
        ? customers
            .where((customer) =>
                customer.creditEnabled && customer.creditLimitMinor > 0)
            .toList()
        : customers;

    final selected = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: selectable.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('Walk-in customer'),
                  subtitle: const Text('No customer account'),
                  selected: _selectedCustomer == null,
                  onTap: () => Navigator.of(sheetContext).pop(_walkInChoice),
                );
              }
              final customer = selectable[index - 1];
              return ListTile(
                title: Text(customer.name),
                subtitle: Text(
                  'Balance ${MoneyFormat.format(customer.balanceMinor)} · '
                  'Limit ${MoneyFormat.format(customer.creditLimitMinor)}',
                ),
                selected: _selectedCustomer?.uuid == customer.uuid,
                onTap: () => Navigator.of(sheetContext).pop(customer),
              );
            },
          ),
        );
      },
    );
    if (!mounted) return;
    if (selected == _walkInChoice) {
      setState(() => _selectedCustomer = null);
    } else if (selected is Customer) {
      setState(() => _selectedCustomer = selected);
    }
  }

  int _parseCashMinor(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return 0;
    return _money(trimmed);
  }

  int get _cashReceivedMinor => _parseCashMinor(_cashController.text);

  bool get _canSubmit {
    if (_submitting || _completed || !_settingsLoaded) return false;
    final cart = context.read<CartController>();
    if (cart.isEmpty) return false;
    if (_paymentMethod == PaymentMethods.cash) {
      return _cashReceivedMinor >= _total;
    }
    if (_paymentMethod == PaymentMethods.split) {
      return _allocations.length >= 2 &&
          !_splitControllers.values.any((c) => _money(c.text) < 0) &&
          _allocations.fold<int>(0, (sum, a) => sum + a.amountMinor) ==
              _total &&
          (_cashAllocation == 0 || _cashReceivedMinor >= _cashAllocation);
    }
    if (_paymentMethod == PaymentMethods.credit) {
      return _selectedCustomer != null;
    }
    return true;
  }

  Future<void> _completeSale() async {
    if (_submitting || !_canSubmit) return;
    final cart = context.read<CartController>();
    final service = context.read<CheckoutService>();
    setState(() => _submitting = true);
    final request = CheckoutRequest(
      items: cart.items,
      saleUuid: _saleUuid,
      allocations:
          _paymentMethod == PaymentMethods.split ? _allocations : const [],
      paymentMethod: _paymentMethod,
      cashReceivedMinor:
          _paymentMethod == PaymentMethods.cash ? _cashReceivedMinor : 0,
      cardReference: _paymentMethod != PaymentMethods.cash &&
              _paymentMethod != PaymentMethods.credit
          ? _cardReferenceController.text
          : null,
      customerUuid: _selectedCustomer?.uuid,
      staffUuid: context.read<StaffSession>().staffUuid,
      notes: cart.note.trim().isEmpty ? null : cart.note.trim(),
    );
    final result = await service.completeSale(request);
    if (!mounted) return;
    result.when(
      success: (outcome) {
        _completed = true;
        cart.clear();
        unawaited(_finishSale(outcome));
      },
      failure: (failure) {
        setState(() => _submitting = false);
        showAppSnack(context, failure.message, kind: AppSnackKind.error);
      },
    );
  }

  /// Post-commit step: optional auto-print and receipt navigation. Printing
  /// failure never rolls back the completed sale.
  Future<void> _finishSale(CheckoutOutcome outcome) async {
    final printService = context.read<ReceiptPrintService>();
    final cashierName = context.read<StaffSession>().displayName;
    var printFailed = false;
    try {
      if (await printService.autoPrintEnabled()) {
        await printService.printSale(
          sale: outcome.sale,
          items: outcome.items,
          cashierName: cashierName,
        );
      }
    } catch (_) {
      printFailed = true;
    }
    if (!mounted) return;
    showAppSnack(
      context,
      printFailed
          ? 'Sale completed — printing failed'
          : 'Sale ${outcome.sale.invoiceNumber} completed',
      kind: printFailed ? AppSnackKind.error : AppSnackKind.info,
    );
    setState(() => _submitting = false);
    await AppNavigator.toReceipt(
      context,
      saleUuid: outcome.sale.uuid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = context.watch<CartController>();
    final totals = cart.totals;
    final changeMinor = _paymentMethod == PaymentMethods.cash ||
            _paymentMethod == PaymentMethods.split
        ? (_cashReceivedMinor - _cashAllocation)
        : 0;

    return PopScope(
        canPop: !_submitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Take payment')),
          bottomNavigationBar: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.all(16),
                  child: FilledButton(
                      onPressed: _canSubmit ? _completeSale : null,
                      child: Text(
                          _submitting ? 'Completing...' : 'Complete sale')))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amount due', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      MoneyText(
                        amountMinor: _total,
                        style: MoneyTextStyle.moneyLarge(context),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      _AmountRow(
                          label: 'Subtotal', amountMinor: totals.subtotalMinor),
                      _AmountRow(
                        label: 'Discount',
                        amountMinor: totals.discountMinor,
                      ),
                      _AmountRow(label: 'Tax', amountMinor: totals.taxMinor),
                      const Divider(),
                      _AmountRow(
                        label: 'Total',
                        amountMinor: _total,
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Payment method', style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in const [
                    PaymentMethods.cash,
                    PaymentMethods.creditCard,
                    PaymentMethods.debitCard,
                    PaymentMethods.qr,
                    PaymentMethods.split,
                    PaymentMethods.credit,
                  ])
                    ChoiceChip(
                      label: Text(PaymentMethods.labelOf(method)),
                      selected: _paymentMethod == method,
                      onSelected: _submitting
                          ? null
                          : (_) {
                              setState(() {
                                _paymentMethod = method;
                              });
                            },
                      selectedColor:
                          QubeXCoreColors.primaryBlue.withValues(alpha: 0.2),
                      avatar: Icon(
                        switch (method) {
                          PaymentMethods.cash => Icons.payments_outlined,
                          PaymentMethods.qr => Icons.qr_code,
                          PaymentMethods.split => Icons.call_split,
                          PaymentMethods.credit =>
                            Icons.account_balance_outlined,
                          _ => Icons.credit_card_outlined,
                        },
                        size: 18,
                        color: _paymentMethod == method
                            ? QubeXCoreColors.primaryBlue
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_paymentMethod == PaymentMethods.split) ...[
                const Text(
                    'Allocate the full total between at least two payment methods.'),
                for (final entry in _splitControllers.entries) ...[
                  const SizedBox(height: 8),
                  TextField(
                      controller: entry.value,
                      enabled: !_submitting,
                      decoration: InputDecoration(
                          labelText:
                              '${PaymentMethods.labelOf(entry.key)} amount',
                          errorText: _money(entry.value.text) < 0
                              ? 'Enter a valid amount'
                              : null),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {})),
                  if (entry.key != PaymentMethods.cash &&
                      _money(entry.value.text) > 0)
                    TextField(
                        controller: _splitReferences[entry.key],
                        enabled: !_submitting,
                        decoration: InputDecoration(
                            labelText:
                                '${PaymentMethods.labelOf(entry.key)} reference (optional)')),
                ],
                _AmountRow(
                    label: 'Remaining to allocate',
                    amountMinor: _total -
                        _allocations.fold<int>(
                            0, (sum, a) => sum + a.amountMinor)),
              ],
              if (_paymentMethod == PaymentMethods.cash ||
                  (_paymentMethod == PaymentMethods.split &&
                      _cashAllocation > 0)) ...[
                TextField(
                  controller: _cashController,
                  enabled: !_submitting,
                  decoration: InputDecoration(
                    errorText: _cashReceivedMinor < 0
                        ? 'Enter a valid amount with up to two decimals'
                        : null,
                    labelText: 'Cash received',
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 8, children: [
                  for (final amount in [0, 10000, 50000])
                    OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => setState(() {
                                  final value = amount == 0
                                      ? _cashAllocation
                                      : (_cashReceivedMinor < 0
                                              ? 0
                                              : _cashReceivedMinor) +
                                          amount;
                                  _cashController.text =
                                      '${value ~/ 100}.${(value % 100).toString().padLeft(2, '0')}';
                                }),
                        child: Text(amount == 0
                            ? 'Exact'
                            : '+${MoneyFormat.format(amount)}')),
                ]),
                _AmountRow(
                  label: 'Change',
                  amountMinor: changeMinor < 0 ? 0 : changeMinor,
                ),
              ],
              if (PaymentMethods.paid.contains(_paymentMethod) &&
                  _paymentMethod != PaymentMethods.cash) ...[
                TextField(
                  controller: _cardReferenceController,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: 'Payment reference (optional)',
                    prefixIcon: Icon(Icons.credit_card_outlined),
                  ),
                ),
              ],
              TextFormField(
                  initialValue: cart.note,
                  enabled: !_submitting,
                  decoration:
                      const InputDecoration(labelText: 'Sale note (optional)'),
                  onChanged: (value) => cart.note = value),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(
                    _selectedCustomer?.name ?? 'Walk-in customer',
                  ),
                  subtitle: _selectedCustomer != null
                      ? Text(
                          'Balance ${MoneyFormat.format(_selectedCustomer!.balanceMinor)} · '
                          'Limit ${MoneyFormat.format(_selectedCustomer!.creditLimitMinor)}',
                        )
                      : Text(
                          _paymentMethod == PaymentMethods.credit
                              ? 'Required for credit sales'
                              : 'No customer account — cash sale',
                        ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _submitting || _customerLoading ? null : _pickCustomer,
                ),
              ),
              if (_customerLoading)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                ),
              const SizedBox(height: 24),
              if (cart.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Add products to the cart before checkout.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ));
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final int amountMinor;
  final bool emphasize;

  const _AmountRow({
    required this.label,
    required this.amountMinor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.bodyMedium,
            ),
          ),
          MoneyText(
            amountMinor: amountMinor,
            style: emphasize
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
