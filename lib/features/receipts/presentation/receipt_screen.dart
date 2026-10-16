import 'dart:io';

import '../data/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/routes.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../core/widgets/empty_state.dart';
import '../../sales/data/sale_repository.dart';
import '../../sales/domain/sale.dart';
import '../../sales/domain/sale_item.dart';
import '../../staff/application/staff_session.dart';
import '../data/receipt_print_service.dart';
import '../data/receipt_pdf_service.dart';
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
      showAppSnack(context, 'Receipt sent to printer');
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context,
          error is PrinterException ? error.message : 'Printing failed',
          kind: AppSnackKind.error);
    }
  }

  Future<void> _savePdf() async {
    final receipt = _receipt;
    if (receipt == null) return;
    try {
      final file = await ReceiptPdfService().save(receipt);
      await Share.shareXFiles([XFile(file.path)],
          text: 'Receipt ${receipt.invoiceNumber}');
    } catch (error) {
      if (mounted)
        showAppSnack(context, 'Could not create PDF: $error',
            kind: AppSnackKind.error);
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
          if (receipt != null)
            IconButton(
              tooltip: 'Download PDF',
              onPressed: _savePdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
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
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                    child: Column(
                      children: [
                        receipt?.logoPath?.isNotEmpty == true
                            ? Image.file(
                                File(receipt!.logoPath!),
                                width: 112,
                                height: 96,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/branding/qubexcore.png',
                                  width: 100,
                                  height: 96,
                                ),
                              )
                            : Image.asset('assets/branding/qubexcore.png',
                                width: 100, height: 96),
                        Text(
                          'QubeXCore',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          receipt?.storeName ?? 'QubeXCore',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (receipt != null &&
                            receipt.branchName.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            receipt.branchName.trim(),
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
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
                        if (receipt != null &&
                            receipt.hotline.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Hotline: ${receipt.hotline.trim()}',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 4),
                        if (receipt != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 10, bottom: 12),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            color: Colors.black87,
                            child: Text(
                              'TAX INVOICE',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        if (receipt != null)
                          _ReceiptMeta(
                            label: 'Invoice No',
                            value: receipt.invoiceNumber,
                          ),
                        if (_sale != null) ...[
                          _ReceiptMeta(
                            label: 'Date',
                            value: receipt!.formattedDate,
                          ),
                          _ReceiptMeta(
                            label: 'Time',
                            value: receipt.formattedTime,
                          ),
                        ],
                        if (receipt?.cashierName?.trim().isNotEmpty ==
                            true) ...[
                          _ReceiptMeta(
                            label: 'Cashier',
                            value: receipt!.cashierName!.trim(),
                          ),
                        ],
                        if (receipt?.terminalNumber.trim().isNotEmpty ==
                            true) ...[
                          _ReceiptMeta(
                            label: 'Terminal',
                            value: receipt!.terminalNumber.trim(),
                          ),
                        ],
                        if (receipt?.customerName?.trim().isNotEmpty ==
                            true) ...[
                          _ReceiptMeta(
                            label: 'Customer',
                            value: receipt!.customerName!.trim(),
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
                          Container(
                            color: Colors.black87,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 7,
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Item',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 38,
                                  child: Text(
                                    'Qty',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 88,
                                  child: Text(
                                    'Total',
                                    textAlign: TextAlign.right,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...receipt.lines.map(
                            (line) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${line.quantityText} × ${line.productName}\n'
                                      '@ ${MoneyFormat.format(line.unitPriceMinor)}'
                                      '${line.barcode?.trim().isNotEmpty == true ? '\\n${line.barcode}' : ''}',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 38,
                                    child: Text(
                                      line.quantityText,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 88,
                                    child: MoneyText(
                                      amountMinor: line.lineTotalMinor,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
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
                          Container(
                            margin: const EdgeInsets.only(top: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            color: Colors.black87,
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'TOTAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                MoneyText(
                                  amountMinor: receipt.totalMinor,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ReceiptRow(
                            label: 'Cash received',
                            amountMinor: receipt.amountPaidMinor,
                          ),
                          _ReceiptRow(
                            label: 'Balance',
                            amountMinor: receipt.amountDueMinor,
                          ),
                          Text(
                            'Products: ${receipt.lines.length} · Total quantity: ${receipt.lines.fold<double>(0, (sum, line) => sum + line.quantity)}',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (receipt.changeMinor > 0)
                            _ReceiptRow(
                              label: 'Change',
                              amountMinor: receipt.changeMinor,
                            ),
                          const SizedBox(height: 8),
                          Text(
                            'Method: ${receipt.paymentMethod.toUpperCase()}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
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
                if (receipt != null)
                  OutlinedButton.icon(
                    onPressed: _savePdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Save / share PDF'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => AppNavigator.toMainShell(context),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Back to Home'),
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
                  ? theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    )
                  : theme.textTheme.bodyLarge,
            ),
          ),
          MoneyText(
            amountMinor: amountMinor,
            style: emphasize
                ? theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  )
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _ReceiptMeta extends StatelessWidget {
  final String label;
  final String value;

  const _ReceiptMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(label, style: style)),
          const Text(':  '),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
