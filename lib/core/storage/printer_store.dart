import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's selected Bluetooth printer device.
class PrinterStore {
  PrinterStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  static const _keyAddress = 'jolinx.printerAddress';
  static const _keyName = 'jolinx.printerName';
  static const _keyPaperWidth = 'jolinx.printerPaperWidth';

  final FlutterSecureStorage _storage;

  Future<String?> getAddress() => _storage.read(key: _keyAddress);
  Future<String?> getName() => _storage.read(key: _keyName);
  Future<String?> getPaperWidth() => _storage.read(key: _keyPaperWidth);

  Future<void> save(String address, String name) async {
    await _storage.write(key: _keyAddress, value: address);
    await _storage.write(key: _keyName, value: name);
  }

  Future<void> savePaperWidth(String width) async {
    await _storage.write(key: _keyPaperWidth, value: width);
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyAddress);
    await _storage.delete(key: _keyName);
    await _storage.delete(key: _keyPaperWidth);
  }
}

/// Tracks the selected printer device.
class PrinterController extends Notifier<PrinterState> {
  @override
  PrinterState build() => const PrinterState();

  Future<void> restore() async {
    final store = ref.read(printerStoreProvider);
    final address = await store.getAddress();
    final name = await store.getName();
    if (address != null && name != null) {
      state = PrinterState(address: address, name: name);
    }
  }

  Future<void> selectPrinter(String address, String name) async {
    state = PrinterState(address: address, name: name);
    await ref.read(printerStoreProvider).save(address, name);
  }

  Future<void> clearPrinter() async {
    state = const PrinterState();
    await ref.read(printerStoreProvider).clear();
  }
}

class PrinterState {
  const PrinterState({this.address, this.name});

  final String? address;
  final String? name;

  bool get hasPrinter => address != null && name != null;
}

final printerStoreProvider = Provider<PrinterStore>((_) => PrinterStore());

final printerControllerProvider =
    NotifierProvider<PrinterController, PrinterState>(PrinterController.new);
