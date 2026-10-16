import '../../../core/theme/money_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_snack.dart';
import '../data/mobile_barcode_scanner.dart';
import '../../pos/domain/cart_controller.dart';
import '../../pos/domain/cart_item.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/barcode_scanner.dart';

class ScanScreen extends StatefulWidget {
  /// Optional scanner; tests inject a fake, production uses the camera.
  final BarcodeScanner? scanner;

  const ScanScreen({super.key, this.scanner});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with WidgetsBindingObserver {
  bool _paused = false;
  Future<void> _queue = Future.value();
  static const _debounceWindow = Duration(milliseconds: 1500);

  late final BarcodeScanner _scanner;
  late final bool _ownsScanner;
  StreamSubscription<String>? _subscription;
  final _manualController = TextEditingController();
  String? _lastCode;
  DateTime _lastCodeAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsScanner = widget.scanner == null;
    _scanner = widget.scanner ?? MobileBarcodeScanner();
    _subscription = _scanner.codes.listen(_onCameraCode);
    _scanner.addListener(_onScannerChanged);
  }

  void _onScannerChanged() {
    if (mounted) setState(() {});
  }

  void _onCameraCode(String code) {
    if (_paused || ModalRoute.of(context)?.isCurrent == false) return;
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastCodeAt) < _debounceWindow) {
      return;
    }
    _lastCode = code;
    _lastCodeAt = now;
    _queue = _queue.then((_) async {
      if (mounted && !_paused) await _handleCode(code);
    });
  }

  Future<void> _handleCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    try {
      final products = context.read<ProductRepository>();
      final product = await products.findByBarcode(trimmed);
      if (!mounted || _paused) return;
      if (product == null || product.isArchived || !product.isActive) {
        showAppSnack(context, 'Product not found', kind: AppSnackKind.error);
        return;
      }
      _addToCart(product);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Unable to look up barcode',
            kind: AppSnackKind.error);
      }
    }
  }

  void _addToCart(Product product) {
    final cart = context.read<CartController>();
    final result = cart.addItem(CartItem.fromProduct(product));
    final message = switch (result) {
      CartChangeResult.ok => 'Added ${product.name}',
      CartChangeResult.capped => 'Added ${product.name} — only '
          '${product.stockQuantity.toStringAsFixed(0)} in stock',
      CartChangeResult.atLimit => 'Only '
          '${product.stockQuantity.toStringAsFixed(0)} in stock',
      CartChangeResult.outOfStock => '${product.name} is out of stock',
    };
    showAppSnack(
      context,
      message,
      kind: result == CartChangeResult.outOfStock
          ? AppSnackKind.error
          : AppSnackKind.info,
    );
  }

  void _submitManual() {
    final code = _manualController.text.trim();
    if (code.isEmpty) return;
    _manualController.clear();
    unawaited(_handleCode(code));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _scanner.removeListener(_onScannerChanged);
    if (_ownsScanner) _scanner.dispose();
    _manualController.dispose();
    super.dispose();
  }

  Widget _permissionCard() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_photography_outlined, size: 56),
            SizedBox(height: 16),
            Text(
              'Camera permission denied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'Allow camera access in system settings to scan barcodes, '
              'or enter the code manually below.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview() {
    if (_scanner.permissionDenied) return _permissionCard();
    final scanner = _scanner;
    if (scanner is MobileBarcodeScanner) {
      return MobileScanner(
        controller: scanner.controller,
        errorBuilder: (context, error) {
          if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
            return _permissionCard();
          }
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Camera unavailable — enter the barcode manually below.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
      );
    }
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 72),
          SizedBox(height: 12),
          Text('Scanner ready'),
        ],
      ),
    );
  }

  Future<void> _pause(bool value) async {
    _paused = value;
    final scanner = _scanner;
    if (scanner is MobileBarcodeScanner) {
      try {
        if (value) {
          await scanner.controller.stop();
        } else {
          await scanner.controller.start();
        }
      } catch (_) {/* Preview provides camera errors. */}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_pause(state != AppLifecycleState.resumed ||
        ModalRoute.of(context)?.isCurrent == false));
  }

  Future<void> _search() async {
    await _pause(true);
    if (!mounted) return;
    try {
      final products = await context.read<ProductRepository>().list();
      if (!mounted) return;
      var query = '';
      final selected = await showModalBottomSheet<Product>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => StatefulBuilder(builder: (context, update) {
                final matches = products
                    .where((p) =>
                        p.isActive &&
                        !p.isArchived &&
                        [p.name, p.sku ?? '', p.barcode ?? ''].any((v) =>
                            v.toLowerCase().contains(query.toLowerCase())))
                    .toList();
                return SizedBox(
                    height: MediaQuery.sizeOf(context).height * .8,
                    child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16,
                            MediaQuery.viewInsetsOf(context).bottom),
                        child: Column(children: [
                          TextField(
                              autofocus: true,
                              decoration: const InputDecoration(
                                  labelText: 'Search name, SKU or barcode'),
                              onChanged: (v) => update(() => query = v)),
                          Expanded(
                              child: ListView(children: [
                            for (final product in matches)
                              ListTile(
                                  title: Text(product.name),
                                  subtitle: Text(MoneyFormat.format(
                                      product.sellingPriceMinor)),
                                  onTap: () => Navigator.pop(context, product))
                          ])),
                        ])));
              }));
      if (mounted && selected != null) _addToCart(selected);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Unable to load products',
            kind: AppSnackKind.error);
      }
    } finally {
      if (mounted) await _pause(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    return Scaffold(
      appBar: AppBar(
          title: Text(_scanner.permissionDenied
              ? 'Camera unavailable'
              : 'Ready · Scan a barcode'),
          actions: [
            IconButton(
                tooltip: 'Cart',
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () async {
                  await _pause(true);
                  if (!context.mounted) return;
                  await AppNavigator.toCart(context);
                  if (mounted) await _pause(false);
                }),
            ValueListenableBuilder<bool>(
                valueListenable: _scanner,
                builder: (context, on, _) => IconButton(
                    tooltip: on ? 'Torch on' : 'Torch off',
                    onPressed: _scanner.toggleTorch,
                    icon: Icon(on ? Icons.flash_on : Icons.flash_off))),
          ]),
      body: Stack(children: [
        Positioned.fill(
            child: Padding(
                padding: const EdgeInsets.only(bottom: 220),
                child: Stack(alignment: Alignment.center, children: [
                  Positioned.fill(child: _preview()),
                  if (!_scanner.permissionDenied)
                    IgnorePointer(
                        child: Container(
                            width: 250,
                            height: 140,
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                borderRadius: BorderRadius.circular(16)))),
                ]))),
        DraggableScrollableSheet(
            initialChildSize: .48,
            minChildSize: .32,
            maxChildSize: .85,
            builder: (context, controller) => Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    children: [
                      Center(
                          child: Container(
                              width: 36,
                              height: 4,
                              color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Text(
                                'Cart (${cart.lineCount})',
                                style: Theme.of(context).textTheme.titleLarge)),
                        FilledButton(
                            onPressed: () async {
                              await _pause(true);
                              if (context.mounted) Navigator.pop(context);
                            },
                            child: const Text('Finish scanning'))
                      ]),
                      for (final item in cart.items)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text('${MoneyFormat.format(
                                              item.unitPriceMinor)} each · ${MoneyFormat.format(
                                              item.lineTotalMinor)}'),
                                      Row(children: [
                                        IconButton(
                                            tooltip: 'Decrease quantity',
                                            onPressed: () => cart
                                                .decrement(item.productUuid),
                                            icon: const Icon(Icons.remove)),
                                        Text(item.quantity.toString()),
                                        IconButton(
                                            tooltip: 'Increase quantity',
                                            onPressed: () {
                                              final result = cart
                                                  .increment(item.productUuid);
                                              if (result != CartChangeResult.ok) {
                                                showAppSnack(context,
                                                    'Stock limit reached');
                                              }
                                            },
                                            icon: const Icon(Icons.add)),
                                        const Spacer(),
                                        IconButton(
                                            tooltip: 'Remove item',
                                            onPressed: () => cart
                                                .removeItem(item.productUuid),
                                            icon: const Icon(Icons.close)),
                                      ]),
                                    ]))),
                      const SizedBox(height: 8),
                      Text('Total · ${MoneyFormat.format(cart.totalMinor)}',
                          style: Theme.of(context).textTheme.titleLarge),
                      OutlinedButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                          label: const Text('Search or add product manually')),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                controller: _manualController,
                                decoration: const InputDecoration(
                                    labelText: 'Enter barcode manually'),
                                onSubmitted: (_) => _submitManual())),
                        TextButton(
                            onPressed: _submitManual, child: const Text('Add'))
                      ]),
                    ]))),
      ]),
    );
  }
}
