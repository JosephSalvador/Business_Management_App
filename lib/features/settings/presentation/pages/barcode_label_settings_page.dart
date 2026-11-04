import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/barcode_settings_store.dart';
import '../../../../l10n/loc.dart';
import '../../../../shared/design_system/app_colors.dart';
import '../../../../shared/widgets/wave_background/wave_background.dart';

class BarcodeLabelSettingsPage extends ConsumerStatefulWidget {
  const BarcodeLabelSettingsPage({super.key});

  @override
  ConsumerState<BarcodeLabelSettingsPage> createState() =>
      _BarcodeLabelSettingsPageState();
}

class _BarcodeLabelSettingsPageState
    extends ConsumerState<BarcodeLabelSettingsPage> {
  final _prefixController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _prefixController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _syncControllers(BarcodeSettings settings) {
    if (!_initialized) {
      _prefixController.text = settings.customPrefix;
      _widthController.text = settings.defaultWidthMm.toStringAsFixed(0);
      _heightController.text = settings.defaultHeightMm.toStringAsFixed(0);
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(barcodeSettingsProvider);
    final loc = context.loc;
    _syncControllers(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.barcodeSettingsTitle),
      ),
      body: WaveBackground(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.resolveBorder(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.barcodeSymbology,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<BarcodeSymbologyPreference>(
                      segments: const [
                        ButtonSegment(
                          value: BarcodeSymbologyPreference.code128,
                          label: Text('Code 128'),
                          icon: Icon(Icons.qr_code_2),
                        ),
                        ButtonSegment(
                          value: BarcodeSymbologyPreference.ean13,
                          label: Text('EAN-13'),
                          icon: Icon(Icons.pin_outlined),
                        ),
                        ButtonSegment(
                          value: BarcodeSymbologyPreference.both,
                          label: Text('Zote (Both)'),
                          icon: Icon(Icons.all_inclusive),
                        ),
                      ],
                      selected: {settings.symbology},
                      onSelectionChanged: (newSelection) {
                        ref.read(barcodeSettingsProvider.notifier).update(
                              settings.copyWith(symbology: newSelection.first),
                            );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _prefixController,
                      decoration: InputDecoration(
                        labelText: loc.barcodeCustomPrefix,
                        hintText: 'e.g. JLX, SHOP',
                        border: const OutlineInputBorder(),
                        helperText: settings.symbology ==
                                BarcodeSymbologyPreference.ean13
                            ? 'Kwa EAN-13, herufi za mwanzo zitageuzwa kuwa namba (20-29)'
                            : 'Kiambishi kitakachotangulia kwenye Code 128',
                      ),
                      onChanged: (val) {
                        ref.read(barcodeSettingsProvider.notifier).update(
                              settings.copyWith(customPrefix: val.trim()),
                            );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.resolveBorder(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vipimo Chaguomsingi vya Lebo (Default Sticker Size)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: loc.barcodeLabelWidth,
                              border: const OutlineInputBorder(),
                              suffixText: 'mm',
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null && parsed > 15) {
                                ref
                                    .read(barcodeSettingsProvider.notifier)
                                    .update(settings.copyWith(
                                        defaultWidthMm: parsed));
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('×',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: loc.barcodeLabelHeight,
                              border: const OutlineInputBorder(),
                              suffixText: 'mm',
                            ),
                            onChanged: (val) {
                              final parsed = double.tryParse(val);
                              if (parsed != null && parsed > 10) {
                                ref
                                    .read(barcodeSettingsProvider.notifier)
                                    .update(settings.copyWith(
                                        defaultHeightMm: parsed));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('50 × 30 mm'),
                          onPressed: () {
                            _widthController.text = '50';
                            _heightController.text = '30';
                            ref.read(barcodeSettingsProvider.notifier).update(
                                  settings.copyWith(
                                      defaultWidthMm: 50, defaultHeightMm: 30),
                                );
                          },
                        ),
                        ActionChip(
                          label: const Text('40 × 30 mm'),
                          onPressed: () {
                            _widthController.text = '40';
                            _heightController.text = '30';
                            ref.read(barcodeSettingsProvider.notifier).update(
                                  settings.copyWith(
                                      defaultWidthMm: 40, defaultHeightMm: 30),
                                );
                          },
                        ),
                        ActionChip(
                          label: const Text('30 × 20 mm'),
                          onPressed: () {
                            _widthController.text = '30';
                            _heightController.text = '20';
                            ref.read(barcodeSettingsProvider.notifier).update(
                                  settings.copyWith(
                                      defaultWidthMm: 30, defaultHeightMm: 20),
                                );
                          },
                        ),
                        ActionChip(
                          label: const Text('60 × 40 mm'),
                          onPressed: () {
                            _widthController.text = '60';
                            _heightController.text = '40';
                            ref.read(barcodeSettingsProvider.notifier).update(
                                  settings.copyWith(
                                      defaultWidthMm: 60, defaultHeightMm: 40),
                                );
                          },
                        ),
                        ActionChip(
                          label: const Text('58mm Roll'),
                          onPressed: () {
                            _widthController.text = '58';
                            _heightController.text = '40';
                            ref.read(barcodeSettingsProvider.notifier).update(
                                  settings.copyWith(
                                      defaultWidthMm: 58, defaultHeightMm: 40),
                                );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: AppColors.resolveBorder(context)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Muonekano wa Lebo (Label Display Options)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      title: const Text('Onyesha Jina la Biashara'),
                      subtitle: const Text('Store / Business name header'),
                      value: settings.showStoreName,
                      onChanged: (val) {
                        ref
                            .read(barcodeSettingsProvider.notifier)
                            .update(settings.copyWith(showStoreName: val));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Onyesha Bei ya Kuuza'),
                      subtitle: const Text('Selling price (TZS)'),
                      value: settings.showPrice,
                      onChanged: (val) {
                        ref
                            .read(barcodeSettingsProvider.notifier)
                            .update(settings.copyWith(showPrice: val));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Onyesha SKU ya Bidhaa'),
                      subtitle: const Text('Product SKU tag'),
                      value: settings.showSku,
                      onChanged: (val) {
                        ref
                            .read(barcodeSettingsProvider.notifier)
                            .update(settings.copyWith(showSku: val));
                      },
                    ),
                    SwitchListTile.adaptive(
                      title: const Text('Weka 2D QR Code Ndogo'),
                      subtitle:
                          const Text('Compact QR code for digital verification'),
                      value: settings.includeQr,
                      onChanged: (val) {
                        ref
                            .read(barcodeSettingsProvider.notifier)
                            .update(settings.copyWith(includeQr: val));
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
