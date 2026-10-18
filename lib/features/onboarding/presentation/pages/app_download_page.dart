import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/device_os_detector.dart';

/// Public landing and download hub enabling store-bypassing client downloads
/// for Android devices and Safari standalone PWA installation on iOS.
class AppDownloadPage extends StatelessWidget {
  const AppDownloadPage({super.key});

  static const String directApkUrl =
      'https://github.com/JosephSalvador/Business_Management_App/releases/download/latest/jolinx-android.apk';
  static const String webPwaUrl = 'https://staging.jolinx-app.pages.dev';
  static const String windowsZipUrl =
      'https://github.com/JosephSalvador/Business_Management_App/releases/download/latest/jolinx-windows-x64.zip';

  @override
  Widget build(BuildContext context) {
    final os = detectDeviceOs();

    return Scaffold(
      backgroundColor: const Color(0xFF061028),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.arrow_left, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/login');
            }
          },
        ),
        title: const Text(
          'Pakua Jolinx App',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero banner
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00C48C).withValues(alpha: 0.4),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C48C).withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      'assets/images/jolinx_logo.png',
                      errorBuilder: (_, __, ___) => const Icon(
                        CupertinoIcons.cube_box_fill,
                        color: Color(0xFF00C48C),
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'JOLINX BUSINESS OS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sakinisha moja kwa moja kwenye simu yako au kompyuta bila Play Store wala App Store.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // Intelligent Detected Device pill
              if (os != DetectedOs.unknown)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C48C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF00C48C).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getOsIcon(os),
                          color: const Color(0xFF00C48C),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Kifaa Chako: ${_getOsDisplayName(os)}',
                          style: const TextStyle(
                            color: Color(0xFF00C48C),
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Dynamically ordered download cards based on detected OS
              ..._buildOrderedCards(context, os),

              const SizedBox(height: 28),

              // Trust badge
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.shield_lefthalf_fill,
                      color: Color(0xFF00C48C),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Data zote zinabaki salama kwenye kifaa chako hata bila mtandao.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOrderedCards(BuildContext context, DetectedOs os) {
    if (os == DetectedOs.ios) {
      return [
        _buildIosCard(context, isPromoted: true),
        const SizedBox(height: 20),
        _buildAndroidCard(context, isPromoted: false),
        const SizedBox(height: 20),
        _buildDesktopCard(context, isPromoted: false),
      ];
    } else if (os == DetectedOs.windows ||
        os == DetectedOs.macos ||
        os == DetectedOs.linux) {
      return [
        _buildDesktopCard(context, isPromoted: true),
        const SizedBox(height: 20),
        _buildAndroidCard(context, isPromoted: false),
        const SizedBox(height: 20),
        _buildIosCard(context, isPromoted: false),
      ];
    } else {
      // Android or unknown default
      return [
        _buildAndroidCard(context, isPromoted: true),
        const SizedBox(height: 20),
        _buildIosCard(context, isPromoted: false),
        const SizedBox(height: 20),
        _buildDesktopCard(context, isPromoted: false),
      ];
    }
  }

  IconData _getOsIcon(DetectedOs os) {
    switch (os) {
      case DetectedOs.android:
        return Icons.android;
      case DetectedOs.ios:
        return Icons.apple;
      case DetectedOs.windows:
        return CupertinoIcons.desktopcomputer;
      case DetectedOs.macos:
        return Icons.apple;
      case DetectedOs.linux:
        return Icons.terminal;
      case DetectedOs.unknown:
        return CupertinoIcons.device_phone_portrait;
    }
  }

  String _getOsDisplayName(DetectedOs os) {
    switch (os) {
      case DetectedOs.android:
        return 'Android';
      case DetectedOs.ios:
        return 'Apple iOS (iPhone/iPad)';
      case DetectedOs.windows:
        return 'Windows PC';
      case DetectedOs.macos:
        return 'macOS';
      case DetectedOs.linux:
        return 'Linux';
      case DetectedOs.unknown:
        return 'Kifaa cha Simu/Kompyuta';
    }
  }

  Widget _buildAndroidCard(BuildContext context, {required bool isPromoted}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPromoted ? const Color(0xFF0F172A) : const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPromoted
              ? const Color(0xFF00C48C).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isPromoted ? 1.5 : 1,
        ),
        boxShadow: isPromoted
            ? [
                BoxShadow(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.android,
                  color: Color(0xFF00C48C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Android (APK ya Moja kwa Moja)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Inafaa kwa simu zote za Android & mashine za POS',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00C48C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              openExternalDownloadUrl(directApkUrl);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Upakuaji wa faili ya APK unaanza sasa...'),
                  backgroundColor: Color(0xFF00C48C),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.arrow_down_circle_fill, size: 20),
            label: const Text(
              'Pakua APK ya Android (Moja kwa moja)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00C48C),
              foregroundColor: const Color(0xFF061028),
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hatua za Kusakinisha:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '1. Bonyeza kitufe cha "Pakua APK ya Android".\n'
                  '2. Simu ikikuuliza, chagua "Ruhusu kutoka chanzo hiki" (Allow unknown apps).\n'
                  '3. Bonyeza "Sakinisha" na ufungue app mara moja.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFFCBD5E1),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosCard(BuildContext context, {required bool isPromoted}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPromoted ? const Color(0xFF0F172A) : const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPromoted
              ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isPromoted ? 1.5 : 1,
        ),
        boxShadow: isPromoted
            ? [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.apple,
                  color: Color(0xFF38BDF8),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'iPhone & iPad (Standalone PWA)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Bila App Store — inafanya kazi kama app ya asili',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPromoted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Kifaa Chako',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.share,
                        color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hatua 1: Gusa kitufe cha Shiriki (Share) chini ya Safari.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(CupertinoIcons.plus_square,
                        color: Color(0xFF00C48C), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hatua 2: Chagua "Ongeza kwenye Skrini ya Mwanzo" (Add to Home Screen).',
                        style: TextStyle(fontSize: 12.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Icon(CupertinoIcons.check_mark_circled,
                        color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hatua 3: Bonyeza "Ongeza" juu kulia. App itatokea kwenye skrini yako.',
                        style: TextStyle(fontSize: 12.5, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => context.go('/login'),
            icon: const Icon(CupertinoIcons.compass, size: 18),
            label: const Text('Fungua Sasa Kwenye Kivinjari'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF38BDF8),
              side: const BorderSide(color: Color(0xFF38BDF8)),
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopCard(BuildContext context, {required bool isPromoted}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPromoted ? const Color(0xFF0F172A) : const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPromoted
              ? const Color(0xFF00C48C).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isPromoted ? 1.5 : 1,
        ),
        boxShadow: isPromoted
            ? [
                BoxShadow(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  CupertinoIcons.desktopcomputer,
                  color: Color(0xFF00C48C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Windows PC & Laptop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Inafaa kwa cashier desk na ripoti za back-office',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (isPromoted)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C48C).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Kifaa Chako',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00C48C),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              openExternalDownloadUrl(windowsZipUrl);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text('Upakuaji wa faili ya Windows (.zip) unaanza sasa...'),
                  backgroundColor: Color(0xFF00C48C),
                ),
              );
            },
            icon: const Icon(CupertinoIcons.arrow_down_circle_fill, size: 20),
            label: const Text(
              'Pakua kwa Windows (PC .zip)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPromoted
                  ? const Color(0xFF00C48C)
                  : const Color(0xFF1E293B),
              foregroundColor:
                  isPromoted ? const Color(0xFF061028) : Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
