import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../l10n/loc.dart';
import '../../shared/design_system/app_colors.dart';

Future<String?> showMobileBarcodeScanner(
  BuildContext context, {
  String? title,
  bool continuous = false,
  ValueChanged<String>? onContinuousScan,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    useSafeArea: true,
    builder: (modalContext) => _MobileBarcodeScannerSheet(
      title: title,
      continuous: continuous,
      onContinuousScan: onContinuousScan,
    ),
  );
}

class _MobileBarcodeScannerSheet extends StatefulWidget {
  const _MobileBarcodeScannerSheet({
    this.title,
    this.continuous = false,
    this.onContinuousScan,
  });

  final String? title;
  final bool continuous;
  final ValueChanged<String>? onContinuousScan;

  @override
  State<_MobileBarcodeScannerSheet> createState() =>
      _MobileBarcodeScannerSheetState();
}

class _MobileBarcodeScannerSheetState
    extends State<_MobileBarcodeScannerSheet>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  late final Animation<double> _laserAnimation;

  bool _isContinuous = false;
  bool _torchOn = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;
  int _scannedCount = 0;

  @override
  void initState() {
    super.initState();
    _isContinuous = widget.continuous;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue?.trim();
    if (code == null || code.isEmpty) return;

    final now = DateTime.now();
    if (_lastScannedCode == code &&
        _lastScanTime != null &&
        now.difference(_lastScanTime!).inMilliseconds < 1200) {
      return; // Debounce immediate repeats
    }

    _lastScannedCode = code;
    _lastScanTime = now;
    HapticFeedback.mediumImpact();

    if (_isContinuous) {
      setState(() => _scannedCount++);
      widget.onContinuousScan?.call(code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanned: $code'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final titleText = widget.title ?? loc.barcodeScannerTitle;

    return Stack(
      children: [
        // Camera Viewfinder
        Positioned.fill(
          child: MobileScanner(
            controller: _controller,
            onDetect: _handleBarcodeCapture,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined,
                          color: Colors.white70, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Kamera haipatikani au ruhusa imekataliwa.',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Funga'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Darkened Mask with Viewfinder Reticle
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final boxWidth = constraints.maxWidth * 0.75;
              final boxHeight = boxWidth * 0.65;

              return Stack(
                children: [
                  Center(
                    child: Container(
                      width: boxWidth,
                      height: boxHeight,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // 4 Corner brackets
                          Positioned(
                            top: 0,
                            left: 0,
                            child: _CornerBracket(isTop: true, isLeft: true),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: _CornerBracket(isTop: true, isLeft: false),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: _CornerBracket(isTop: false, isLeft: true),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: _CornerBracket(isTop: false, isLeft: false),
                          ),
                          // Animated Laser
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: boxHeight * _laserAnimation.value,
                                left: 8,
                                right: 8,
                                child: Container(
                                  height: 2.5,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.redAccent.withValues(alpha: 0.1),
                                        Colors.redAccent,
                                        Colors.redAccent.withValues(alpha: 0.1),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent.withValues(alpha: 0.8),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),

        // Top App Bar Controls
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                ),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  titleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              // Torch Toggle
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: _torchOn
                      ? Colors.amber.withValues(alpha: 0.9)
                      : Colors.black.withValues(alpha: 0.6),
                ),
                icon: Icon(
                  _torchOn ? Icons.flash_on : Icons.flash_off,
                  color: _torchOn ? Colors.black : Colors.white,
                ),
                onPressed: () async {
                  await _controller.toggleTorch();
                  if (mounted) setState(() => _torchOn = !_torchOn);
                },
              ),
            ],
          ),
        ),

        // Bottom Controls
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                loc.barcodeScannerPrompt,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Camera Switch
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                    onPressed: () => _controller.switchCamera(),
                  ),
                  const SizedBox(width: 16),
                  // Mode Toggle
                  FilterChip(
                    avatar: Icon(
                      _isContinuous ? Icons.repeat : Icons.filter_1,
                      size: 16,
                      color: _isContinuous ? Colors.white : Colors.black87,
                    ),
                    label: Text(
                      _isContinuous
                          ? '${loc.barcodeScanContinuous} ($_scannedCount)'
                          : loc.barcodeScanSingle,
                      style: TextStyle(
                        color: _isContinuous ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selected: _isContinuous,
                    selectedColor: AppColors.primary,
                    onSelected: (val) {
                      setState(() => _isContinuous = val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  const _CornerBracket({required this.isTop, required this.isLeft});
  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    const size = 20.0;
    const thickness = 3.5;
    const color = AppColors.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: color, width: thickness)
              : BorderSide.none,
        ),
      ),
    );
  }
}
