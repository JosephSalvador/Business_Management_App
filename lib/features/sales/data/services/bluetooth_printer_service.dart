// services/bluetooth_printer_service.dart
import 'package:business_management_system/shared/models/printer_model.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../shared/services/printer_storage_service.dart';
import '../../data/models/sale_models.dart';


class BluetoothPrinterService {
  // ignore: unused_field
  static bool _isScanning = false;
  static const int maxChunkSize = 200; // Safe chunk size for Bluetooth LE
  static const int delayBetweenChunks = 50; // ms delay between chunks

  // ---------------------- DEVICE DISCOVERY ----------------------

  static Stream<List<BluetoothDevice>> discoverPrinters() {
    print('🔍 Starting universal Bluetooth scan...');

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      continuousUpdates: true,
      continuousDivisor: 4,
    );

    return FlutterBluePlus.scanResults.map(
      (List<ScanResult> results) {
        final devices = results.map((result) => result.device).toList();

        print('📡 Found ${devices.length} Bluetooth devices');
        for (var device in devices) {
          final name =
              device.platformName.isEmpty ? 'Unknown' : device.platformName;
          print('   📱 $name - ${device.remoteId}');
        }

        return devices;
      },
    );
  }

  // ---------------------- CONNECTION ----------------------

  static Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      print('🔗 Attempting to connect to ${device.platformName}...');

      if (device.isConnected) {
        print('✅ Already connected to ${device.platformName}');
        return true;
      }

      await device.connect(timeout: const Duration(seconds: 10));
      await Future.delayed(const Duration(seconds: 2));

      if (device.isConnected) {
        print('✅ Successfully connected to ${device.platformName}');
        return true;
      } else {
        print('❌ Connection failed to ${device.platformName}');
        return false;
      }
    } catch (e) {
      print('❌ Failed to connect to ${device.platformName}: $e');
      return false;
    }
  }

  // ---------------------- PRINTING ----------------------

  static Future<void> printToDevice(BluetoothDevice device, Sale sale,
      {bool savePrinter = true}) async {
    try {
      print('🖨️ Attempting to print to ${device.platformName}...');

      final List<int> bytes = await _generateReceiptBytes(sale);
      print('📄 Generated ${bytes.length} bytes of receipt data');

      List<BluetoothService> services = await device.discoverServices();
      print('📡 Found ${services.length} services on ${device.platformName}');

      BluetoothCharacteristic? writeCharacteristic;

      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          final canWrite = characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse;

          if (canWrite) {
            writeCharacteristic = characteristic;
            break;
          }
        }
        if (writeCharacteristic != null) break;
      }

      if (writeCharacteristic == null) {
        throw Exception('Could not find a writable characteristic for printing');
      }

      await _sendDataInChunks(writeCharacteristic, bytes);

      print('✅ Receipt sent to ${device.platformName} successfully!');

      if (savePrinter) {
        await _savePrinterAfterSuccess(device);
      }

      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      print('❌ Print failed on ${device.platformName}: $e');
      rethrow;
    }
  }

  static Future<void> _sendDataInChunks(
      BluetoothCharacteristic characteristic, List<int> data) async {
    print('📦 Sending ${data.length} bytes in chunks of $maxChunkSize...');

    for (int i = 0; i < data.length; i += maxChunkSize) {
      final end = i + maxChunkSize < data.length ? i + maxChunkSize : data.length;
      final chunk = data.sublist(i, end);

      print('   📤 Sending chunk ${(i ~/ maxChunkSize) + 1}: ${chunk.length} bytes');

      try {
        if (characteristic.properties.writeWithoutResponse) {
          await characteristic.write(chunk, withoutResponse: true);
        } else {
          await characteristic.write(chunk);
        }
        await Future.delayed(
            const Duration(milliseconds: delayBetweenChunks));
      } catch (e) {
        print('   ❌ Failed to write chunk: $e');
        throw Exception('Failed to write data chunk: $e');
      }
    }

    print('✅ All chunks sent successfully!');
  }

  // ---------------------- SAVED PRINTER ----------------------

  static SavedPrinter _deviceToSavedPrinter(BluetoothDevice device) {
    return SavedPrinter(
      id: device.remoteId.str,
      name: device.platformName.isEmpty ? 'Unknown Printer' : device.platformName,
      address: device.remoteId.str,
      lastConnected: DateTime.now(),
      isConnected: true,
    );
  }

  static Future<void> _savePrinterAfterSuccess(BluetoothDevice device) async {
    try {
      final savedPrinter = _deviceToSavedPrinter(device);
      await PrinterStorageService.saveDefaultPrinter(savedPrinter);
      print('💾 Printer saved as default: ${device.platformName}');
    } catch (e) {
      print('❌ Failed to save printer: $e');
    }
  }

  static Future<BluetoothDevice?> connectToSavedPrinter() async {
    try {
      final savedPrinter = await PrinterStorageService.getDefaultPrinter();
      if (savedPrinter == null) {
        print('ℹ️ No saved printer found');
        return null;
      }

      print('🔍 Looking for saved printer: ${savedPrinter.name}');
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      BluetoothDevice? foundDevice;
      final subscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          if (result.device.remoteId.str == savedPrinter.address) {
            foundDevice = result.device;
            print('✅ Found saved printer: ${foundDevice!.platformName}');
            break;
          }
        }
      });

      await Future.delayed(const Duration(seconds: 8));
      await FlutterBluePlus.stopScan();
      subscription.cancel();

      if (foundDevice != null) {
        final connected = await connectToDevice(foundDevice!);
        if (connected) {
          print('✅ Successfully reconnected to saved printer: ${foundDevice!.platformName}');
          return foundDevice;
        }
      }

      print('❌ Could not reconnect to saved printer');
      return null;
    } catch (e) {
      print('❌ Error connecting to saved printer: $e');
      return null;
    }
  }

  // ---------------------- RECEIPT GENERATION ----------------------

  static Future<List<int>> _generateReceiptBytes(Sale sale) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    bytes += generator.text(
      'RECEIPT',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      sale.receiptNumber,
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1),
    );

    bytes += generator.text(
      _formatDate(sale.date),
      styles: const PosStyles(align: PosAlign.center, height: PosTextSize.size1),
    );

    bytes += generator.hr();

    if (sale.customerName != 'Walk-in Customer') {
      bytes += generator.text('Cust: ${sale.customerName}');
    }
    if (sale.customerTin.isNotEmpty) {
      bytes += generator.text('TIN: ${sale.customerTin}');
    }
    bytes += generator.text('Pay: ${sale.paymentMethod}');
    if (sale.paymentReference.isNotEmpty) {
      bytes += generator.text('Ref: ${sale.paymentReference}');
    }

    bytes += generator.hr();
    bytes += generator.text('ITEMS', styles: const PosStyles(align: PosAlign.center, bold: true));

    for (final item in sale.items) {
      String productName = item.productName;
      if (productName.length > 20) {
        productName = '${productName.substring(0, 17)}...';
      }

      bytes += generator.text(productName);
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${_formatCompactCurrency(item.unitPrice)}',
          width: 6,
          styles: const PosStyles(height: PosTextSize.size1),
        ),
        PosColumn(
          text: _formatCompactCurrency(item.unitPrice * item.quantity),
          width: 6,
          styles: const PosStyles(align: PosAlign.right, height: PosTextSize.size1),
        ),
      ]);
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Subtotal:', width: 6),
      PosColumn(text: _formatCompactCurrency(sale.amount), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'VAT ${sale.vatRate == 'A' ? '18%' : '16%'}:', width: 6),
      PosColumn(text: _formatCompactCurrency(sale.vatAmount), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr(ch: '=', linesAfter: 1);
    bytes += generator.row([
      PosColumn(text: 'TOTAL:', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: _formatCompactCurrency(sale.totalAmount), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += generator.hr();
    bytes += generator.text('VFD: ${sale.vfdSerial}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Thank you!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  static String _formatCompactCurrency(double amount) {
    return 'TZS ${amount.toStringAsFixed(0)}';
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------- UTILS ----------------------

  static Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      print('🛑 Bluetooth scan stopped');
    } catch (e) {
      print('❌ Error stopping scan: $e');
    }
  }

  static Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isAvailable;
    } catch (e) {
      print('❌ Bluetooth not available: $e');
      return false;
    }
  }

  static Future<bool> isBluetoothOn() async {
    try {
      return await FlutterBluePlus.isOn;
    } catch (e) {
      print('❌ Bluetooth not on: $e');
      return false;
    }
  }

  static Future<bool> checkPermissions() async {
    try {
      print('🔐 Checking Bluetooth permissions...');

      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      final locationStatus = await Permission.location.status;

      if (!bluetoothScanStatus.isGranted) {
        await Permission.bluetoothScan.request();
      }
      if (!bluetoothConnectStatus.isGranted) {
        await Permission.bluetoothConnect.request();
      }
      if (!locationStatus.isGranted) {
        await Permission.location.request();
      }

      return bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted;
    } catch (e) {
      print('❌ Permission error: $e');
      return false;
    }
  }
}
