import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'ios_pwa_helper.dart';

/// Interactive helper banner displayed to iPhone / iPad Safari users
/// guiding them to add Jolinx to their Home Screen as an offline standalone PWA.
class IosInstallPromptBanner extends StatefulWidget {
  const IosInstallPromptBanner({super.key});

  @override
  State<IosInstallPromptBanner> createState() => _IosInstallPromptBannerState();
}

class _IosInstallPromptBannerState extends State<IosInstallPromptBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed || !isIosSafariBrowser()) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00C48C).withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C48C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  CupertinoIcons.device_phone_portrait,
                  color: Color(0xFF00C48C),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sakinisha Jolinx kwenye iPhone',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Tumia kama app kamili bila kufungua Safari na ufanye kazi bila mtandao.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF64748B), size: 18),
                onPressed: () => setState(() => _dismissed = true),
                tooltip: 'Funga',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.share,
                      color: Color(0xFF38BDF8),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '1. Gusa kitufe cha Shiriki (Share) chini ya Safari.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.plus_square,
                      color: Color(0xFF00C48C),
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '2. Chagua "Ongeza kwenye Skrini ya Mwanzo" (Add to Home Screen).',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
