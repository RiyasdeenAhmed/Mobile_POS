import '../../../app/routes.dart';
import '../../payments/domain/payment.dart';
import '../../receipts/data/printer_service.dart';
import '../../../core/database/settings_repository.dart';
import '../../../core/platform/retail_files.dart';
import '../../invoices/data/invoice_destination.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/money_text.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../invoices/data/invoice_pdf_service.dart';
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
  List<Payment> _payments = [];
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
    final payments = await repository.listPayments(sale.id!);
    if (!mounted) return;
    setState(() {
      _sale = sale;
      _items = items;
      _payments = payments;
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
      showAppSnack(context, 'Receipt sent to printer');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context,
          error is PrinterException ? error.message : 'Printing failed',
          kind: AppSnackKind.error);
    }
  }

  Future<File?> _renderInvoiceFile() async {
    final sale = _sale;
    if (sale == null) return null;
    final service = context.read<InvoicePdfService>();
    final cashierName = context.read<StaffSession>().displayName;
    final bytes = await service.render(
      sale: sale,
      items: _items,
      cashierName: cashierName,
    );
    final documents = await getTemporaryDirectory();
    return service.save(
      Directory('${documents.path}/invoices'),
      fileName: '${sale.invoiceNumber}.pdf',
      bytes: bytes,
    );
  }

  bool _exporting = false;
  Future<void> _downloadInvoice({bool saveAs = false}) async {
    if (_sale == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final destination =
          InvoiceDestination(context.read<SettingsRepository>(), RetailFiles());
      final bytes = await context.read<InvoicePdfService>().render(
          sale: _sale!,
          items: _items,
          cashierName: context.read<StaffSession>().displayName);
      final saved = await destination.save('${_sale!.invoiceNumber}.pdf', bytes,
          saveAs: saveAs);
      if (mounted && saved != null) {
        showAppSnack(context, 'Invoice saved to $saved');
      }
    } catch (_) {
      if (mounted) {
        showAppSnack(context,
            'Could not save invoice. Use Save As to choose an accessible destination.',
            kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareInvoice() async {
    final sale = _sale;
    if (sale == null) return;
    final service = context.read<InvoicePdfService>();
    try {
      final file = await _renderInvoiceFile();
      if (file == null) return;
      await service.share(file);
      if (!mounted) return;
      showAppSnack(context, 'Sharing ${sale.invoiceNumber}');
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, 'Could not share invoice',
          kind: AppSnackKind.error);
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
                                'Method: ${_sale?.paymentMethod ?? ''}\n'
                                        '${_payments.map((p) => "${PaymentMethods.labelOf(p.paymentMethod)}: ${MoneyFormat.format(p.amountMinor)}").join("\n")}'
                                    .toUpperCase(),
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => AppNavigator.toReceipt(context,saleUuid: _sale!.uuid),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('Receipt preview'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _print,
                          icon: const Icon(Icons.print_outlined, size: 18),
                          label: const Text('Print Receipt'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              _exporting ? null : () => _downloadInvoice(),
                          icon: const Icon(Icons.download_outlined, size: 18),
                          label: const Text('Save Invoice'),
                        ),
                        OutlinedButton.icon(
                            onPressed: _exporting
                                ? null
                                : () => _downloadInvoice(saveAs: true),
                            icon: const Icon(Icons.save_as_outlined),
                            label: const Text('Save As')),
                        OutlinedButton.icon(
                          onPressed: _shareInvoice,
                          icon: const Icon(Icons.share_outlined, size: 18),
                          label: const Text('Share Invoice'),
                        ),
                      ],
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
                                '${item.quantityText} × '
                                    '${MoneyFormat.format(item.unitPriceMinor)}',
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
