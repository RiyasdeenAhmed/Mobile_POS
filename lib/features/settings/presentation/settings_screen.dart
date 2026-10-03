import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/database/settings_repository.dart';
import '../../../core/theme/money_text.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storeNameController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  final _printerNameController = TextEditingController();

  bool _allowNegativeStock = false;
  bool _printerEnabled = false;
  bool _autoPrint = false;
  String _printerWidth = '32';
  String _invoiceSequence = '0';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    _currencySymbolController.dispose();
    _invoicePrefixController.dispose();
    _taxPercentController.dispose();
    _receiptFooterController.dispose();
    _printerNameController.dispose();
    super.dispose();
  }

  String _bpsToPercent(int bps) {
    if (bps % 100 == 0) return '${bps ~/ 100}';
    final value = bps / 100;
    return value.toString().replaceFirst(RegExp(r'\.0$'), '');
  }

  Future<void> _load() async {
    final repository = context.read<SettingsRepository>();
    final settings = await repository.loadCoreSettings();
    if (!mounted) return;
    setState(() {
      _storeNameController.text = settings['store_name'] ?? '';
      _storeAddressController.text = settings['store_address'] ?? '';
      _storePhoneController.text = settings['store_phone'] ?? '';
      _currencySymbolController.text = settings['currency_symbol'] ?? 'Rs';
      _invoicePrefixController.text = settings['invoice_prefix'] ?? 'INV';
      _taxPercentController.text =
          _bpsToPercent(int.tryParse(settings['tax_rate_bps'] ?? '') ?? 0);
      _receiptFooterController.text = settings['receipt_footer'] ?? '';
      _printerNameController.text = settings['printer_name'] ?? '';
      _allowNegativeStock = settings['allow_negative_stock'] == '1';
      _printerEnabled = settings['printer_enabled'] == '1';
      _autoPrint = settings['auto_print_receipt'] == '1';
      _printerWidth = settings['printer_width'] == '42' ? '42' : '32';
      _invoiceSequence = settings['invoice_sequence'] ?? '0';
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final percent = double.parse(_taxPercentController.text.trim());
    final bps = (percent * 100).round();
    final repository = context.read<SettingsRepository>();
    setState(() => _saving = true);
    await repository.setString(
      'store_name',
      _storeNameController.text.trim(),
    );
    await repository.setString(
      'store_address',
      _storeAddressController.text.trim(),
    );
    await repository.setString(
      'store_phone',
      _storePhoneController.text.trim(),
    );
    final symbol = _currencySymbolController.text.trim();
    await repository.setString('currency_symbol', symbol);
    await repository.setString(
      'invoice_prefix',
      _invoicePrefixController.text.trim(),
    );
    await repository.setString('tax_rate_bps', '$bps');
    await repository.setString(
      'allow_negative_stock',
      _allowNegativeStock ? '1' : '0',
    );
    await repository.setString(
      'receipt_footer',
      _receiptFooterController.text.trim(),
    );
    await repository.setString(
      'printer_enabled',
      _printerEnabled ? '1' : '0',
    );
    await repository.setString(
      'printer_name',
      _printerNameController.text.trim(),
    );
    await repository.setString('printer_width', _printerWidth);
    await repository.setString('auto_print_receipt', _autoPrint ? '1' : '0');
    if (symbol.isNotEmpty) {
      MoneyFormat.defaultSymbol = symbol;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  String? _requiredText(String? value, String message) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  }

  String? _taxValidator(String? value) {
    final text = value?.trim() ?? '';
    final parsed = double.tryParse(text);
    if (parsed == null) return 'Enter a valid percentage';
    if (parsed < 0 || parsed > 100) return 'Must be between 0 and 100';
    return null;
  }

  Widget _sectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(title, style: theme.textTheme.titleMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _sectionTitle(theme, 'Store'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _storeNameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) =>
                        _requiredText(v, 'Store name is required'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storeAddressController,
                    decoration: const InputDecoration(labelText: 'Address'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _storePhoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
            _sectionTitle(theme, 'Sales'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _currencySymbolController,
                    decoration: const InputDecoration(
                      labelText: 'Currency symbol',
                      helperText: 'Shown on prices, receipts, and totals',
                    ),
                    validator: (v) => _requiredText(
                      v,
                      'Currency symbol is required',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoicePrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice prefix',
                      helperText: 'Example: INV-0001',
                    ),
                    validator: (v) =>
                        _requiredText(v, 'Invoice prefix is required'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _taxPercentController,
                    decoration: const InputDecoration(
                      labelText: 'Tax rate (%)',
                      helperText: '0 disables tax; supports decimals',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _taxValidator,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Allow negative stock'),
                    subtitle: const Text(
                      'Sell items even when stock runs out',
                    ),
                    value: _allowNegativeStock,
                    onChanged: (value) {
                      setState(() => _allowNegativeStock = value);
                    },
                  ),
                ],
              ),
            ),
            _sectionTitle(theme, 'Receipt'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _receiptFooterController,
                    decoration: const InputDecoration(
                      labelText: 'Receipt footer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Printer enabled'),
                    subtitle: const Text(
                      'Use the configured printer service',
                    ),
                    value: _printerEnabled,
                    onChanged: (value) {
                      setState(() => _printerEnabled = value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto-print receipts'),
                    subtitle: const Text(
                      'Print automatically after each completed sale',
                    ),
                    value: _autoPrint,
                    onChanged: (value) {
                      setState(() => _autoPrint = value);
                    },
                  ),
                  TextFormField(
                    controller: _printerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Printer name',
                      helperText: 'Optional label for the paired printer',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _printerWidth,
                    decoration: const InputDecoration(
                      labelText: 'Paper width',
                    ),
                    items: const [
                      DropdownMenuItem(value: '32', child: Text('58 mm (32)')),
                      DropdownMenuItem(value: '42', child: Text('80 mm (42)')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _printerWidth = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            _sectionTitle(theme, 'General'),
            ListTile(
              leading: const Icon(Icons.confirmation_number_outlined),
              title: const Text('Invoice sequence'),
              subtitle: Text(_invoiceSequence),
            ),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Staff accounts'),
              subtitle: Text('Manage staff from More → Staff'),
            ),
            const AboutListTile(
              icon: Icon(Icons.info_outline),
              applicationName: 'QubeXCore POS',
              applicationVersion: '0.1.0',
              applicationLegalese: 'Offline-first retail POS',
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save settings'),
        ),
      ),
    );
  }
}
