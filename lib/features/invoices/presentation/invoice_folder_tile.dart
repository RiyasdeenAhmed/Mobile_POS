import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/database/settings_repository.dart';
import '../../../core/platform/retail_files.dart';
import '../data/invoice_destination.dart';

class InvoiceFolderTile extends StatefulWidget {
  const InvoiceFolderTile({super.key});
  @override
  State<InvoiceFolderTile> createState() => _InvoiceFolderTileState();
}

class _InvoiceFolderTileState extends State<InvoiceFolderTile> {
  String? _folder;
  bool _busy = false;
  InvoiceDestination get service =>
      InvoiceDestination(context.read<SettingsRepository>(), RetailFiles());
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final folder = await service.folder;
    if (mounted) setState(() => _folder = folder);
  }

  Future<void> _change(bool reset) async {
    setState(() => _busy = true);
    try {
      if (reset) {
        await service.reset();
      } else {
        await service.choose();
      }
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Could not change invoice folder. Choose an accessible folder and try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Invoice destination',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_folder == null
                ? 'Ask where to save each invoice'
                : Uri.decodeComponent(_folder!.split('/').last)),
            Wrap(children: [
              TextButton(
                  onPressed: _busy ? null : () => _change(false),
                  child: const Text('Change folder')),
              TextButton(
                  onPressed:
                      _busy || _folder == null ? null : () => _change(true),
                  child: const Text('Reset'))
            ]),
          ])));
}
