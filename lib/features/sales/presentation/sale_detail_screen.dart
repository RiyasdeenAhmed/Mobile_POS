import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../receipts/data/receipt_print_service.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../../staff/application/staff_session.dart';

class SaleDetailScreen extends StatefulWidget {
  final String? saleUuid;

  const SaleDetailScreen({super.key, this.saleUuid});

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  Sale? _sale;
  List<SaleItem> _items = <SaleItem>[];
  bool _loading = true;
  String? _error;

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
      setState(() {
        _loading = false;
        _error = 'Sale reference is missing';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final repository = context.read<SaleRepository>();
    final sale = await repository.findByUuid(saleUuid);
    if (!mounted) return;
    if (sale == null || sale.id == null) {
      setState(() {
        _sale = null;
        _items = <SaleItem>[];
        _loading = false;
        _error = 'Sale not found';
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

  Future<void> _print() async {
    final sale = _sale;
    if (sale == null) return;
    try {
      await context.read<ReceiptPrintService>().printSale(
            sale: sale,
            items: _items,
            cashierName: context.read<StaffSession>().displayName,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt sent to printer')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printing failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale detail'),
        actions: [
          if (_sale != null)
            IconButton(
              tooltip: 'Print',
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Sale unavailable',
                  message: _error,
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_sale != null) ...[
                      Text('Invoice', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        _sale!.invoiceNumber,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _sale!.saleAt,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _DetailRow(
                              label: 'Subtotal',
                              amountMinor: _sale?.subtotalMinor ?? 0,
                            ),
                            _DetailRow(
                              label: 'Discount',
                              amountMinor: _sale?.discountMinor ?? 0,
                            ),
                            _DetailRow(
                              label: 'Tax',
                              amountMinor: _sale?.taxMinor ?? 0,
                            ),
                            const Divider(),
                            _DetailRow(
                              label: 'Total',
                              amountMinor: _sale?.totalMinor ?? 0,
                              emphasize: true,
                            ),
                            _DetailRow(
                              label: 'Paid',
                              amountMinor: _sale?.amountPaidMinor ?? 0,
                            ),
                            if ((_sale?.changeMinor ?? 0) > 0)
                              _DetailRow(
                                label: 'Change',
                                amountMinor: _sale!.changeMinor,
                              ),
                            if ((_sale?.amountDueMinor ?? 0) > 0)
                              _DetailRow(
                                label: 'Due',
                                amountMinor: _sale!.amountDueMinor,
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Method: ${_sale?.paymentMethod ?? ''}'
                                    .toUpperCase(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Items', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_items.isEmpty)
                      const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No items recorded',
                      )
                    else
                      ..._items.map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(item.productName),
                            subtitle: Text(
                              [
                                '${item.quantity} × ${MoneyFormat.format(item.unitPriceMinor)}',
                                if (item.productSku != null) item.productSku!,
                              ].join(' · '),
                            ),
                            trailing: MoneyText(
                              amountMinor: item.lineTotalMinor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final int amountMinor;
  final bool emphasize;

  const _DetailRow({
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
