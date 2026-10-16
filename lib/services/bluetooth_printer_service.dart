
import 'package:bluetooth_classic/bluetooth_classic.dart';

class BluetoothPrinterService {
  final BluetoothClassic bluetooth = BluetoothClassic();

  Future<void> initialize() async {
    await bluetooth.initPermissions();
  }

  Future<List<Device>> getPrinters() async {
    return await bluetooth.getPairedDevices();
  }

  Future<void> connect(String address) async {
    await bluetooth.connect(
      address,
      "00001101-0000-1000-8000-00805f9b34fb",
    );
  }

  Future<void> printTest() async {
    final commands = [
      'SIZE 60 mm,40 mm',
      'GAP 2 mm,0 mm',
      'DIRECTION 1',
      'CLS',
      'TEXT 30,30,"3",0,1,1,"POS TEST"',
      'TEXT 30,90,"2",0,1,1,"Hello Xprinter"',
      'PRINT 1,1',
    ].join('\r\n') + '\r\n';

    await bluetooth.write(commands);
  }

  Future<void> disconnect() async {
    await bluetooth.disconnect();
  }
}
