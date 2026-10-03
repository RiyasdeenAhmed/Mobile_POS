import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';

class ReceiptScreen extends StatefulWidget {
  final String? saleUuid;

  const ReceiptScreen({super.key, this.saleUuid});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Sale? _sale;
  List<SaleItem> _items = <SaleItem>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final saleUuid = widget.saleUuid;
    if (saleUuid == null || saleUuid.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final repository = context.read<SaleRepository>();
    final sale = await repository.findByUuid(saleUuid);
    if (!mounted) return;
    if (sale == null || sale.id == null) {
      setState(() {
        _sale = null;
        _loading = false;
      });
      return;
    }
    final items = await repository.listItems(sale.id!);
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text('QubeXCore', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          _sale?.invoiceNumber ?? 'Receipt preview',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_sale != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _sale!.saleAt,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        if (_sale == null)
                          const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No sale data',
                            message: 'Complete a sale to see a receipt.',
                          )
                        else ...[
                          ..._items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item.quantity} × ${item.productName}',
                                    ),
                                  ),
                                  MoneyText(
                                    amountMinor: item.lineTotalMinor,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          _ReceiptRow(
                            label: 'Total',
                            amountMinor: _sale!.totalMinor,
                            emphasize: true,
                          ),
                          _ReceiptRow(
                            label: 'Paid',
                            amountMinor: _sale!.amountPaidMinor,
                          ),
                          if (_sale!.changeMinor > 0)
                            _ReceiptRow(
                              label: 'Change',
                              amountMinor: _sale!.changeMinor,
                            ),
                          if (_sale!.amountDueMinor > 0)
                            _ReceiptRow(
                              label: 'Due',
                              amountMinor: _sale!.amountDueMinor,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Method: ${_sale!.paymentMethod.toUpperCase()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => AppNavigator.toMainShell(context),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Back to Dashboard'),
                ),
              ],
            ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final int amountMinor;
  final bool emphasize;

  const _ReceiptRow({
    required this.label,
    required this.amountMinor,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: emphasize
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
          MoneyText(
            amountMinor: amountMinor,
            style: emphasize ? theme.textTheme.titleSmall : null,
          ),
        ],
      ),
    );
  }
}
