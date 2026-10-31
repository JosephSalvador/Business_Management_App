import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../config/app_config.dart';
import '../platform/native_installer_service.dart';

/// Metadata describing an available application release.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.minSupportedBuild,
    required this.androidApkUrl,
    required this.webPwaUrl,
    required this.releaseNotesSw,
    required this.releaseNotesEn,
    required this.forceUpdate,
    required this.releasedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
      minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 0,
      androidApkUrl: json['androidApkUrl'] as String? ?? '',
      webPwaUrl: json['webPwaUrl'] as String? ?? '',
      releaseNotesSw: json['releaseNotesSw'] as String? ??
          'Maboresho ya mfumo na utendaji kazi.',
      releaseNotesEn: json['releaseNotesEn'] as String? ??
          'System enhancements and performance optimizations.',
      forceUpdate: json['forceUpdate'] as bool? ?? false,
      releasedAt: json['releasedAt'] != null
          ? DateTime.tryParse(json['releasedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  final String version;
  final int buildNumber;
  final int minSupportedBuild;
  final String androidApkUrl;
  final String webPwaUrl;
  final String releaseNotesSw;
  final String releaseNotesEn;
  final bool forceUpdate;
  final DateTime releasedAt;
}

/// Service that coordinates OTA update discovery, background downloads,
/// and native in-place upgrading for store-bypassing client deployments.
class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  /// Current compile-time fallback build number (incremented on each release).
  static const int currentClientBuildNumber = 69;
  static const String currentClientVersionName = '1.0.0';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(minutes: 5),
    ),
  );

  /// Checks if a newer build exists on the backend API or fallback CDN.
  Future<AppUpdateInfo?> checkForUpdate() async {
    if (kIsWeb) return null;

    try {
      final config = AppConfig.load();
      final uri = config.apiBaseUrl.replace(path: '/api/v1/app/version');

      final response = await _dio.getUri(uri);
      if (response.statusCode != 200 || response.data == null) {
        return null;
      }

      final data = response.data is Map<String, dynamic>
          ? response.data as Map<String, dynamic>
          : Map<String, dynamic>.from(response.data as Map);

      final updateInfo = AppUpdateInfo.fromJson(data);

      // Inspect local build number from native package manager if available
      int localBuild = currentClientBuildNumber;
      final nativeVersion = await NativeInstallerService.getAppVersion();
      if (nativeVersion != null && nativeVersion.versionCode > 0) {
        localBuild = nativeVersion.versionCode;
      }

      if (updateInfo.buildNumber > localBuild) {
        return updateInfo;
      }

      return null;
    } catch (e) {
      debugPrint('AppUpdateService: update check skipped or failed: $e');
      return null;
    }
  }

  /// Displays the interactive update sheet and manages the download & install lifecycle.
  static Future<void> promptUpdateDialog(
    BuildContext context,
    AppUpdateInfo info,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => _AppUpdateDialog(info: info),
    );
  }
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.info});

  final AppUpdateInfo info;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _statusMessage = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
      _statusMessage = 'Inapakua toleo jipya (0%)...';
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/jolinx-update-${widget.info.buildNumber}.apk';
      final file = File(targetPath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        widget.info.androidApkUrl,
        targetPath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            final percent = received / total;
            setState(() {
              _progress = percent;
              final percentDisplay = (percent * 100).toInt();
              final receivedMb = (received / (1024 * 1024)).toStringAsFixed(1);
              final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
              _statusMessage =
                  'Inapakua: $receivedMb MB / $totalMb MB ($percentDisplay%)';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Upakuaji umekamilika! Inakagua ruhusa...';
      });

      final canInstall =
          await NativeInstallerService.canRequestPackageInstalls();
      if (!canInstall) {
        if (!mounted) return;
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Tafadhali ruhusu usakinishaji wa programu kutoka chanzo hiki kwenye mipangilio ya simu yako.';
        });
        await NativeInstallerService.openInstallPermissionSettings();
        return;
      }

      setState(() {
        _statusMessage = 'Inafungua kisakinishi cha Android...';
      });

      final success = await NativeInstallerService.installApk(targetPath);
      if (!success && mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Imeshindwa kufungua kisakinishi. Tafadhali jaribu tena au fungua faili lililopakuliwa.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Hitilafu wakati wa kupakua: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF0F172A),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C48C).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_down_circle_fill,
                    color: Color(0xFF00C48C),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Toleo Jipya Linapatikana',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'v${widget.info.version} (Build ${widget.info.buildNumber})',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'Maboresho Yaliyojumuishwa:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Text(
                widget.info.releaseNotesSw,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFFE2E8F0),
                  height: 1.4,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 12,
                ),
              ),
            ],
            if (_isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00C48C)),
                borderRadius: BorderRadius.circular(8),
                minHeight: 8,
              ),
              const SizedBox(height: 10),
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!widget.info.forceUpdate && !_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Baadaye',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isDownloading ? null : _startUpdate,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(CupertinoIcons.arrow_down_to_line, size: 18),
                  label: Text(_isDownloading ? 'Inapakua...' : 'Sasisha Sasa'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C48C),
                    foregroundColor: const Color(0xFF061028),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
