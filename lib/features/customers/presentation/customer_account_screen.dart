import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../data/customer_ledger_repository.dart';
import '../data/customer_repository.dart';
import '../data/repayment_service.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger_entry.dart';

class CustomerAccountScreen extends StatefulWidget {
  final String? customerUuid;

  const CustomerAccountScreen({super.key, this.customerUuid});

  @override
  State<CustomerAccountScreen> createState() => _CustomerAccountScreenState();
}

class _CustomerAccountScreenState extends State<CustomerAccountScreen> {
  Future<(Customer, List<CustomerLedgerEntry>)?>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _reload() {
    final future = _load();
    setState(() {
      _future = future;
    });
  }

  Future<(Customer, List<CustomerLedgerEntry>)?> _load() async {
    final uuid = widget.customerUuid;
    if (uuid == null) return null;
    final repository = context.read<CustomerRepository>();
    final ledger = context.read<CustomerLedgerRepository>();
    final customer = await repository.findByUuid(uuid);
    if (customer == null || customer.id == null) return null;
    final entries = await ledger.listByCustomer(customer.id!);
    return (customer, entries);
  }

  static String _entryLabel(CustomerLedgerEntry entry) {
    if (entry.isDebt) return 'Credit sale';
    if (entry.isRepayment) return 'Repayment';
    if (entry.isReturnCredit) return 'Return credit';
    return entry.entryType;
  }

  static String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('d MMM yyyy, HH:mm').format(parsed.toLocal());
  }

  Future<void> _recordRepayment(Customer customer) async {
    final amountController = TextEditingController();
    String method = 'Cash';
    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Record repayment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Outstanding: ${MoneyFormat.format(customer.balanceMinor)}',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '${MoneyFormat.defaultSymbol} ',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Method'),
                items: const [
                  DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'Card', child: Text('Card')),
                  DropdownMenuItem(
                    value: 'Bank transfer',
                    child: Text('Bank transfer'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setDialogState(() => method = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    var amountText = amountController.text.trim();
    int? amountMinor;
    if (amountText.isNotEmpty) {
      amountText =
          amountText.replaceAll(RegExp('^${MoneyFormat.defaultSymbol}'), '');
      try {
        amountMinor = MoneyFormat.parseMajorToMinor(amountText);
      } on FormatException {
        amountMinor = null;
      }
    }
    if (amountMinor == null || amountMinor <= 0) {
      if (!mounted) return;
      showAppSnack(
        context,
        'Enter an amount greater than zero',
        kind: AppSnackKind.error,
      );
      return;
    }

    final service = context.read<RepaymentService>();
    final result = await service.recordRepayment(
      customerUuid: customer.uuid,
      amountMinor: amountMinor,
      note: method,
    );
    if (!mounted) return;
    result.when(
      success: (int newBalance) {
        showAppSnack(
          context,
          'Repayment recorded — balance ${MoneyFormat.format(newBalance)}',
        );
        _reload();
      },
      failure: (failure) {
        showAppSnack(context, failure.message, kind: AppSnackKind.error);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer account')),
      body: FutureBuilder<(Customer, List<CustomerLedgerEntry>)?>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (!snapshot.hasData && !snapshot.hasError) {
            return const Center(child: CircularProgressIndicator());
          }
          if (data == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Customer not found',
              message: 'This account may have been removed.',
            );
          }
          final (customer, entries) = data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      customer.name.isEmpty
                          ? '?'
                          : customer.name[0].toUpperCase(),
                    ),
                  ),
                  title: Text(customer.name),
                  subtitle: Text(customer.phone ?? 'No phone on file'),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Outstanding balance',
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      MoneyText(amountMinor: customer.balanceMinor),
                      const SizedBox(height: 8),
                      Text(
                        'Credit limit: ${MoneyFormat.format(customer.creditLimitMinor)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (customer.balanceMinor > 0) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _recordRepayment(customer),
                            icon: const Icon(Icons.payments_outlined),
                            label: const Text('Record repayment'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Ledger', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (entries.isEmpty)
                const EmptyState(
                  icon: Icons.history,
                  title: 'No ledger activity',
                  message: 'Debt and repayments will appear here.',
                )
              else
                ...entries.map((entry) => _LedgerRow(entry: entry)),
            ],
          );
        },
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final CustomerLedgerEntry entry;

  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = entry.amountMinor >= 0;
    final amountColor = positive ? Colors.red : Colors.green;
    final amountText =
        '${positive ? '+' : '-'}${MoneyFormat.format(entry.amountMinor.abs())}';
    final reference = entry.saleUuid ?? entry.note ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
          _CustomerAccountScreenState._entryLabel(entry),
          style: theme.textTheme.bodyMedium,
        ),
        subtitle: Text(
          [
            _CustomerAccountScreenState._formatDate(entry.createdAt),
            if (reference.isNotEmpty) reference,
          ].join(' · '),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amountText,
              style: theme.textTheme.bodyMedium?.copyWith(color: amountColor),
            ),
            Text(
              'Bal ${MoneyFormat.format(entry.balanceAfterMinor)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
