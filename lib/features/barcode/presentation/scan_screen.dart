import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
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

class _ScanScreenState extends State<ScanScreen> {
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
    _ownsScanner = widget.scanner == null;
    _scanner = widget.scanner ?? MobileBarcodeScanner();
    _subscription = _scanner.codes.listen(_onCameraCode);
    _scanner.addListener(_onScannerChanged);
  }

  void _onScannerChanged() {
    if (mounted) setState(() {});
  }

  void _onCameraCode(String code) {
    final now = DateTime.now();
    if (code == _lastCode && now.difference(_lastCodeAt) < _debounceWindow) {
      return;
    }
    _lastCode = code;
    _lastCodeAt = now;
    unawaited(_handleCode(code));
  }

  Future<void> _handleCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return;
    final products = context.read<ProductRepository>();
    final product = await products.findByBarcode(trimmed);
    if (!mounted) return;
    if (product == null || product.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product not found')),
      );
      return;
    }
    _addToCart(product);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan barcode'),
        actions: [
          IconButton(
            tooltip: 'Cart',
            onPressed: () => AppNavigator.toCart(context),
            icon: Badge(
              isLabelVisible: cart.isNotEmpty,
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _scanner,
            builder: (context, torchOn, _) => IconButton(
              tooltip: torchOn ? 'Torch on' : 'Torch off',
              onPressed: _scanner.toggleTorch,
              icon: Icon(torchOn ? Icons.flash_on : Icons.flash_off),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _preview()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualController,
                    decoration: const InputDecoration(
                      labelText: 'Enter barcode manually',
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submitManual(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _submitManual,
                  child: const Text('Add'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
