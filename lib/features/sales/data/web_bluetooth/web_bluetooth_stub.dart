import 'dart:typed_data';

import 'web_bluetooth_platform.dart';

export 'web_bluetooth_platform.dart';

/// Stub implementation for non-web platforms.
class WebBluetoothPrinterStub implements WebBluetoothPrinterPlatform {
  @override
  bool get isSupported => false;

  @override
  Future<bool> printBytes(Uint8List bytes) async => false;
}

WebBluetoothPrinterPlatform createWebBluetoothPrinter() =>
    WebBluetoothPrinterStub();
