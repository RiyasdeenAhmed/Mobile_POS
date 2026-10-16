import 'dart:io';

import '../../pos/domain/cart_controller.dart';
import '../../invoices/presentation/invoice_folder_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_selector/file_selector.dart' as fs;
import 'package:path_provider/path_provider.dart';

import '../../../app/theme_controller.dart';
import '../../../core/database/settings_repository.dart';
import '../../../core/theme/money_text.dart';
import '../../../core/theme/app_ui.dart';
import '../../../core/widgets/app_snack.dart';
import '../../../features/backups/data/backup_service.dart';
import '../../staff/application/staff_session.dart';
import '../../receipts/data/android_bluetooth_printer.dart';
import '../../receipts/data/printer_service.dart';

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
  final _branchNameController = TextEditingController();
  final _hotlineController = TextEditingController();
  final _terminalNumberController = TextEditingController();
  final _currencySymbolController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _taxPercentController = TextEditingController();
  final _receiptFooterController = TextEditingController();
  final _printerNameController = TextEditingController();
  final _printerOffsetController = TextEditingController(text: '0');
  final _printerContentWidthController = TextEditingController();
  final _printerLogoWidthController = TextEditingController();
  String _printerAddress = '';
  BluetoothPrinterStatus? _bluetoothStatus;
  bool _testingPrinter = false;
  String _printerProtocol = 'tspl';
  String _printerLastError = '';

  bool _allowNegativeStock = false;
  bool _printerEnabled = false;
  bool _autoPrint = false;
  String _printerWidth = '32';
  String _printerFontScale = '1';
  String _invoiceSequence = '0';
  bool _loading = true;
  bool _saving = false;
  bool _backupBusy = false;
  bool _tapToPayEnabled = false;
  String _sessionTimeoutMinutes = '0';
  String _businessLogoPath = '';

  Future<String?> _askBackupPassword({required bool restore}) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(restore ? 'Restore backup' : 'Create encrypted backup'),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Backup password'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(restore ? 'Validate' : 'Create')),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createBackup() async {
    final password = await _askBackupPassword(restore: false);
    if (!mounted || password == null || password.isEmpty) return;
    setState(() => _backupBusy = true);
    try {
      final archive = await context
          .read<BackupService>()
          .createEncrypted(password: password);
      if (mounted)
        showAppSnack(context, 'Encrypted backup created at ${archive.path}');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Backup failed: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final file = await fs.openFile(acceptedTypeGroups: [
      const fs.XTypeGroup(label: 'QubeXCore backup', extensions: ['qbxbackup']),
    ]);
    if (!mounted || file == null) return;
    final password = await _askBackupPassword(restore: true);
    if (!mounted || password == null || password.isEmpty) return;
    setState(() => _backupBusy = true);
    try {
      final safety = await context
          .read<BackupService>()
          .prepareRestore(File(file.path), password: password);
      if (mounted)
        showAppSnack(context,
            'Backup validated. Safety copy prepared at ${safety.path}. Restart the app before replacing its database.');
    } catch (error) {
      if (mounted) showAppSnack(context, 'Restore validation failed: $error');
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }

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
    _branchNameController.dispose();
    _hotlineController.dispose();
    _terminalNumberController.dispose();
    _currencySymbolController.dispose();
    _invoicePrefixController.dispose();
    _taxPercentController.dispose();
    _receiptFooterController.dispose();
    _printerNameController.dispose();
    _printerOffsetController.dispose();
    _printerContentWidthController.dispose();
    _printerLogoWidthController.dispose();
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
      _branchNameController.text = settings['branch_name'] ?? '';
      _hotlineController.text = settings['hotline'] ?? '';
      _terminalNumberController.text = settings['terminal_number'] ?? '';
      _currencySymbolController.text = settings['currency_symbol'] ?? 'Rs';
      _invoicePrefixController.text = settings['invoice_prefix'] ?? 'INV';
      _taxPercentController.text =
          _bpsToPercent(int.tryParse(settings['tax_rate_bps'] ?? '') ?? 0);
      _receiptFooterController.text = settings['receipt_footer'] ?? '';
      _printerNameController.text = settings['printer_name'] ?? '';
      _printerAddress = settings['printer_address'] ?? '';
      _allowNegativeStock = settings['allow_negative_stock'] == '1';
      _printerEnabled = settings['printer_enabled'] == '1';
      _autoPrint = settings['auto_print_receipt'] == '1';
      _printerWidth = settings['printer_width'] == '32' ? '32' : '42';
      _printerOffsetController.text = settings['printer_offset_dots'] ?? '0';
      _printerContentWidthController.text = settings['printer_content_width_dots'] ??
          (_printerWidth == '42' ? '608' : '432');
      _printerLogoWidthController.text = settings['printer_logo_width_dots'] ??
          (_printerWidth == '42' ? '360' : '260');
      _printerFontScale = settings['printer_font_scale'] == '2' ? '2' : '1';
      _invoiceSequence = settings['invoice_sequence'] ?? '0';
      _tapToPayEnabled = settings['tap_to_pay_enabled'] == '1';
      _sessionTimeoutMinutes = settings['session_timeout_minutes'] ?? '0';
      _businessLogoPath = settings['business_logo_path'] ?? '';
      _printerProtocol =
          settings['printer_protocol'] == 'tspl' ? 'tspl' : 'esc_pos';
      _printerLastError = settings['printer_last_error'] ?? '';
      _loading = false;
    });
    try {
      final status = await AndroidBluetoothPrinter.status();
      if (mounted) setState(() => _bluetoothStatus = status);
    } catch (_) {}
  }

  Future<void> _choosePrinter() async {
    try {
      final devices = await AndroidBluetoothPrinter.pairedDevices();
      if (!mounted) return;
      final picked = await showModalBottomSheet<BluetoothPrinterDevice>(
        context: context,
        builder: (sheet) => SafeArea(
          child: devices.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'No paired devices. Pair the printer in Android Bluetooth settings first.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: () {
                          AndroidBluetoothPrinter.openPairingSettings();
                          Navigator.pop(sheet);
                        },
                        icon: const Icon(Icons.settings_bluetooth),
                        label: const Text('Open Bluetooth settings')),
                  ]),
                )
              : ListView(
                  shrinkWrap: true,
                  children: devices
                      .map((d) => ListTile(
                          title: Text(d.name),
                          subtitle: Text(d.address),
                          leading: const Icon(Icons.print_outlined),
                          onTap: () => Navigator.pop(sheet, d)))
                      .toList()),
        ),
      );
      if (picked != null && mounted)
        setState(() {
          _printerAddress = picked.address;
          _printerNameController.text = picked.name;
          _printerEnabled = true;
        });
    } on PrinterException catch (error) {
      if (mounted) showAppSnack(context, error.message);
    }
  }

  Future<void> _testPrinter() async {
    if (_printerAddress.isEmpty || _testingPrinter) return;
    setState(() => _testingPrinter = true);
    final repository = context.read<SettingsRepository>();
    try {
      await AndroidBluetoothPrinter(_printerAddress).test(
        _printerProtocol == 'tspl'
            ? PrinterProtocol.tspl
            : PrinterProtocol.escPos,
        paperWidthMm: _printerWidth == '42' ? 80 : 58,
      );
      await repository.setString('printer_last_error', '');
      if (mounted) setState(() => _printerLastError = '');
      if (mounted) showAppSnack(context, 'Test receipt sent');
    } on PrinterException catch (error) {
      await repository.setString('printer_last_error', error.message);
      if (mounted) setState(() => _printerLastError = error.message);
      if (mounted) showAppSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
  }

  Future<void> _diagnosePrinter() async {
    if (_printerAddress.isEmpty || _testingPrinter) return;
    setState(() => _testingPrinter = true);
    try {
      await AndroidBluetoothPrinter(_printerAddress).diagnostic(
        paperWidthMm: _printerWidth == '42' ? 80 : 58,
      );
      if (mounted) {
        showAppSnack(context,
            'Diagnostic test sent. Check edge markers, reverse text, barcode, and QR code.');
      }
    } on PrinterException catch (error) {
      if (mounted)
        showAppSnack(context, error.message, kind: AppSnackKind.error);
    } finally {
      if (mounted) setState(() => _testingPrinter = false);
    }
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
    await repository.setString('branch_name', _branchNameController.text.trim());
    await repository.setString('hotline', _hotlineController.text.trim());
    await repository.setString(
        'terminal_number', _terminalNumberController.text.trim());
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
    await repository.setString('printer_address', _printerAddress);
    await repository.setString('printer_width', _printerWidth);
    await repository.setString(
      'printer_offset_dots',
      _printerOffsetController.text.trim().isEmpty
          ? '0'
          : _printerOffsetController.text.trim(),
    );
    await repository.setString(
      'printer_content_width_dots',
      _printerContentWidthController.text.trim(),
    );
    await repository.setString(
      'printer_logo_width_dots',
      _printerLogoWidthController.text.trim(),
    );
    await repository.setString('printer_font_scale', _printerFontScale);
    await repository.setString('auto_print_receipt', _autoPrint ? '1' : '0');
    await repository.setString(
        'tap_to_pay_enabled', _tapToPayEnabled ? '1' : '0');
    await repository.setString(
        'session_timeout_minutes', _sessionTimeoutMinutes);
    await repository.setString('business_logo_path', _businessLogoPath);
    await repository.setString('printer_protocol', _printerProtocol);
    if (symbol.isNotEmpty) {
      MoneyFormat.defaultSymbol = symbol;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    context.read<CartController?>()?.setTaxRate(bps);
    final timeout = int.tryParse(_sessionTimeoutMinutes) ?? 0;
    context.read<StaffSession?>()?.configureTimeout(Duration(minutes: timeout));
    showAppSnack(context, 'Settings saved');
  }

  Future<void> _chooseBusinessLogo() async {
    final picked = await fs.openFile(
      acceptedTypeGroups: [
        const fs.XTypeGroup(
            label: 'Business logo', extensions: ['png', 'jpg', 'jpeg', 'webp']),
      ],
    );
    if (picked == null || !mounted) return;
    final directory = await getApplicationDocumentsDirectory();
    final target = File(
        '${directory.path}${Platform.pathSeparator}business_logo${picked.name.toLowerCase().endsWith('.png') ? '.png' : '.jpg'}');
    await target.writeAsBytes(await picked.readAsBytes(), flush: true);
    if (mounted) setState(() => _businessLogoPath = target.path);
  }

  Future<void> _removeBusinessLogo() async {
    final path = _businessLogoPath;
    setState(() => _businessLogoPath = '');
    if (path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
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
    return QubeXSectionTitle(title: title);
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _businessLogoPath.isEmpty
                            ? const Icon(Icons.storefront_outlined, size: 34)
                            : Image.file(File(_businessLogoPath),
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image_outlined)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _chooseBusinessLogo,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(_businessLogoPath.isEmpty
                                  ? 'Choose business logo'
                                  : 'Change business logo'),
                            ),
                            if (_businessLogoPath.isNotEmpty)
                              TextButton.icon(
                                onPressed: _removeBusinessLogo,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Remove logo'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _branchNameController,
                    decoration: const InputDecoration(
                      labelText: 'Branch name',
                      helperText: 'Optional, shown on receipts',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hotlineController,
                    decoration: const InputDecoration(
                      labelText: 'Hotline',
                      helperText: 'Optional support number shown on receipts',
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _terminalNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Terminal number',
                      helperText: 'Optional unit or terminal identifier',
                    ),
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
                  SwitchListTile.adaptive(
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
                  SwitchListTile.adaptive(
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
                  SwitchListTile.adaptive(
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
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.bluetooth_searching),
                    title: const Text('Bluetooth printer'),
                    subtitle: Text(_printerAddress.isEmpty
                        ? 'Choose a paired printer'
                        : '${_printerNameController.text} · $_printerAddress'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _choosePrinter,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      switch (_bluetoothStatus) {
                        null => 'Bluetooth status unavailable',
                        BluetoothPrinterStatus(supported: false) =>
                          'Bluetooth is not supported on this device',
                        BluetoothPrinterStatus(enabled: false) =>
                          'Bluetooth is turned off',
                        BluetoothPrinterStatus(permissionGranted: false) =>
                          'Nearby devices permission is required',
                        _ => 'Bluetooth is ready',
                      },
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  if (_printerAddress.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _printerProtocol,
                      decoration: const InputDecoration(
                        labelText: 'Printer protocol',
                        helperText: 'Use ESC/POS for receipt printing',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'esc_pos',
                          child: Text('ESC/POS receipt mode'),
                        ),
                        DropdownMenuItem(
                          value: 'tspl',
                          child: Text('TSPL label mode (compatibility test)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _printerProtocol = value);
                        }
                      },
                    ),
                  if (_printerAddress.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: _testingPrinter ? null : _testPrinter,
                      icon: const Icon(Icons.print_outlined),
                      label:
                          Text(_testingPrinter ? 'Testing...' : 'Test printer'),
                    ),
                  if (_printerAddress.isNotEmpty && _printerProtocol == 'tspl')
                    OutlinedButton.icon(
                      onPressed: _testingPrinter ? null : _diagnosePrinter,
                      icon: const Icon(Icons.rule_outlined),
                      label: const Text('Run printer diagnostic'),
                    ),
                  if (_printerAddress.isNotEmpty &&
                      _printerLastError.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Last print error: $_printerLastError',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _printerContentWidthController,
                    decoration: const InputDecoration(
                      labelText: 'Content width (dots)',
                      helperText: '80mm XP-365B default: 608 dots printable width',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 240) {
                        return 'Enter a width of at least 240 dots';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _printerOffsetController,
                    decoration: const InputDecoration(
                      labelText: 'Horizontal offset (dots)',
                      helperText: 'Use a small negative or positive value to fine-tune centering',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    validator: (value) =>
                        int.tryParse(value?.trim() ?? '') == null
                            ? 'Enter a whole number'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _printerLogoWidthController,
                    decoration: const InputDecoration(
                      labelText: 'Logo width (dots)',
                      helperText: 'The logo remains centered and keeps its aspect ratio',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final parsed = int.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed < 80) {
                        return 'Enter a logo width of at least 80 dots';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _printerFontScale,
                    decoration: const InputDecoration(
                      labelText: 'Printer font size',
                      helperText: 'Use 2x only when the printer has enough horizontal space',
                    ),
                    items: const [
                      DropdownMenuItem(value: '1', child: Text('Standard')),
                      DropdownMenuItem(value: '2', child: Text('Large')),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _printerFontScale = value);
                    },
                  ),
                ],
              ),
            ),
            _sectionTitle(theme, 'Payments & Security'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tap to pay'),
                    subtitle: const Text(
                        'Visible only when a certified provider is configured'),
                    value: _tapToPayEnabled,
                    onChanged: (value) =>
                        setState(() => _tapToPayEnabled = value),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _sessionTimeoutMinutes,
                    decoration:
                        const InputDecoration(labelText: 'Session timeout'),
                    items: const [
                      DropdownMenuItem(value: '0', child: Text('Never')),
                      DropdownMenuItem(value: '5', child: Text('5 minutes')),
                      DropdownMenuItem(value: '15', child: Text('15 minutes')),
                      DropdownMenuItem(value: '30', child: Text('30 minutes')),
                    ],
                    onChanged: (value) {
                      if (value != null)
                        setState(() => _sessionTimeoutMinutes = value);
                    },
                  ),
                ],
              ),
            ),
            _sectionTitle(theme, 'Appearance'),
            _sectionTitle(theme, 'Backup & Restore'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.backup_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text('Protect your store data',
                              style: theme.textTheme.titleSmall)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Encrypted local backups protect your offline store data. Restoring is blocked while a sale is active.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _backupBusy ? null : _createBackup,
                      icon: const Icon(Icons.backup_outlined),
                      label: Text(_backupBusy
                          ? 'Working...'
                          : 'Create encrypted backup'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _backupBusy ? null : _restoreBackup,
                      icon: const Icon(Icons.restore_outlined),
                      label: const Text('Validate and restore backup'),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme applies immediately.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Consumer<ThemeController>(
                    builder: (context, controller, _) {
                      return SegmentedButton<ThemeMode>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            label: Text('System'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            label: Text('Light'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            label: Text('Dark'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {controller.mode},
                        onSelectionChanged: (selection) {
                          controller.setMode(selection.first);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const InvoiceFolderTile(),
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
        child: QubeXPrimaryButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save settings'),
        ),
      ),
    );
  }
}
