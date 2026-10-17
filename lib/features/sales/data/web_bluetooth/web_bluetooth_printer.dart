import 'web_bluetooth_stub.dart'
    if (dart.library.js_interop) 'web_bluetooth_web.dart';

export 'web_bluetooth_platform.dart';

final WebBluetoothPrinterPlatform webBluetoothPrinter =
    createWebBluetoothPrinter();
