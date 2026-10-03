import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/money_text.dart';
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
  bool _customerLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
    });
  }

  @override
  void dispose() {
    _cashController.dispose();
    _cardReferenceController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    if (_paymentMethod != PaymentMethods.credit) return;
    setState(() => _customerLoading = true);
    final repository = context.read<CustomerRepository>();
    await repository.list();
    if (!mounted) return;
    setState(() => _customerLoading = false);
  }

  static const Object _walkInChoice = Object();

  Future<void> _pickCustomer() async {
    setState(() => _customerLoading = true);
    final repository = context.read<CustomerRepository>();
    final customers = await repository.list();
    if (!mounted) return;
    setState(() => _customerLoading = false);

    final selected = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: customers.length + 1,
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
              final customer = customers[index - 1];
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
    return MoneyFormat.parseMajorToMinor(trimmed);
  }

  int get _cashReceivedMinor => _parseCashMinor(_cashController.text);

  bool get _canSubmit {
    if (_submitting) return false;
    final cart = context.read<CartController>();
    if (cart.isEmpty) return false;
    if (_paymentMethod == PaymentMethods.cash) {
      return _cashReceivedMinor >= cart.totalMinor;
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
      paymentMethod: _paymentMethod,
      cashReceivedMinor:
          _paymentMethod == PaymentMethods.cash ? _cashReceivedMinor : 0,
      cardReference: _paymentMethod == PaymentMethods.card
          ? _cardReferenceController.text
          : null,
      customerUuid: _selectedCustomer?.uuid,
      staffUuid: context.read<StaffSession>().staffUuid,
      notes: cart.note.trim().isEmpty ? null : cart.note.trim(),
    );
    final result = await service.completeSale(request);
    if (!mounted) return;
    setState(() => _submitting = false);
    result.when(
      success: (outcome) {
        cart.clear();
        unawaited(_finishSale(outcome));
      },
      failure: (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          printFailed
              ? 'Sale completed — printing failed'
              : 'Sale ${outcome.sale.invoiceNumber} completed',
        ),
      ),
    );
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
    final changeMinor = _paymentMethod == PaymentMethods.cash
        ? (_cashReceivedMinor - totals.totalMinor)
        : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
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
                    amountMinor: totals.totalMinor,
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
                    amountMinor: totals.totalMinor,
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
                PaymentMethods.card,
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
                          if (method == PaymentMethods.credit) {
                            _loadCustomers();
                          }
                        },
                  selectedColor:
                      QubeXCoreColors.warningOrange.withValues(alpha: 0.2),
                  avatar: Icon(
                    method == PaymentMethods.cash
                        ? Icons.payments_outlined
                        : method == PaymentMethods.card
                            ? Icons.credit_card_outlined
                            : Icons.account_balance_outlined,
                    size: 18,
                    color: _paymentMethod == method
                        ? QubeXCoreColors.warningOrange
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_paymentMethod == PaymentMethods.cash) ...[
            TextField(
              controller: _cashController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Cash received',
                hintText: '0.00',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            _AmountRow(
              label: 'Change',
              amountMinor: changeMinor < 0 ? 0 : changeMinor,
            ),
          ],
          if (_paymentMethod == PaymentMethods.card) ...[
            TextField(
              controller: _cardReferenceController,
              enabled: !_submitting,
              decoration: const InputDecoration(
                labelText: 'Card reference (optional)',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
            ),
          ],
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
              onTap: _submitting ? null : _pickCustomer,
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
          ElevatedButton(
            onPressed: _canSubmit ? _completeSale : null,
            child: Text(_submitting ? 'Completing...' : 'Complete sale'),
          ),
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
    );
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
