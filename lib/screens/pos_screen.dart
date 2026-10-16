
import 'package:flutter/material.dart';
import '../services/bluetooth_printer_service.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final printer = BluetoothPrinterService();

  
Future<void> testPrinter() async {
  try {
    await printer.initialize();

    final devices = await printer.getPrinters();

    debugPrint("===== PAIRED BLUETOOTH DEVICES =====");

    for (final device in devices) {
      debugPrint("Name: ${device.name}");
      debugPrint("Address: ${device.address}");
    }

    debugPrint("====================================");

  } catch (e) {
    debugPrint("Bluetooth Error: $e");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS System'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: testPrinter,
          icon: const Icon(Icons.print),
          label: const Text('Test Bluetooth Printer'),
        ),
      ),
    );
  }
}
