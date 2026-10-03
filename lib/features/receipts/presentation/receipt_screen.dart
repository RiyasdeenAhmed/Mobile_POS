import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../../staff/application/staff_session.dart';
import '../data/receipt_print_service.dart';
import '../domain/receipt.dart';

class ReceiptScreen extends StatefulWidget {
  final String? saleUuid;

  const ReceiptScreen({super.key, this.saleUuid});

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  Sale? _sale;
  List<SaleItem> _items = <SaleItem>[];
  Receipt? _receipt;
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
    final receipt = await context.read<ReceiptPrintService>().buildReceipt(
          sale: sale,
          items: items,
          cashierName: context.read<StaffSession>().displayName,
        );
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _items = items;
      _receipt = receipt;
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
    final receipt = _receipt;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        actions: [
          if (receipt != null)
            IconButton(
              tooltip: 'Print',
              onPressed: _print,
              icon: const Icon(Icons.print_outlined),
            ),
        ],
      ),
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
                        Text(
                          receipt?.storeName ?? 'QubeXCore',
                          style: theme.textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                        if (receipt != null &&
                            receipt.storeAddress.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            receipt.storeAddress.trim(),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (receipt != null &&
                            receipt.storePhone.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            receipt.storePhone.trim(),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          receipt?.invoiceNumber ?? 'Receipt preview',
                          style: theme.textTheme.bodySmall,
                        ),
                        if (_sale != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _sale!.saleAt,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (receipt?.cashierName?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Cashier: ${receipt!.cashierName!.trim()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        if (receipt?.customerName?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Customer: ${receipt!.customerName!.trim()}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        if (receipt == null)
                          const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'No sale data',
                            message: 'Complete a sale to see a receipt.',
                          )
                        else ...[
                          ...receipt.lines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${line.quantityText} × '
                                      '${line.productName}',
                                    ),
                                  ),
                                  MoneyText(
                                    amountMinor: line.lineTotalMinor,
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(),
                          _ReceiptRow(
                            label: 'Subtotal',
                            amountMinor: receipt.subtotalMinor,
                          ),
                          if (receipt.discountMinor > 0)
                            _ReceiptRow(
                              label: 'Discount',
                              amountMinor: receipt.discountMinor,
                            ),
                          if (receipt.taxMinor > 0)
                            _ReceiptRow(
                              label: 'Tax',
                              amountMinor: receipt.taxMinor,
                            ),
                          _ReceiptRow(
                            label: 'Total',
                            amountMinor: receipt.totalMinor,
                            emphasize: true,
                          ),
                          _ReceiptRow(
                            label: 'Paid',
                            amountMinor: receipt.amountPaidMinor,
                          ),
                          if (receipt.changeMinor > 0)
                            _ReceiptRow(
                              label: 'Change',
                              amountMinor: receipt.changeMinor,
                            ),
                          if (receipt.amountDueMinor > 0)
                            _ReceiptRow(
                              label: 'Due',
                              amountMinor: receipt.amountDueMinor,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Method: ${receipt.paymentMethod.toUpperCase()}',
                            style: theme.textTheme.bodySmall,
                          ),
                          if (receipt.footer.trim().isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              receipt.footer.trim(),
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (receipt != null)
                  OutlinedButton.icon(
                    onPressed: _print,
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Print receipt'),
                  ),
                const SizedBox(height: 8),
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
