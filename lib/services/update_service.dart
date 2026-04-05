import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final ValueNotifier<double> downloadProgress = ValueNotifier(0);
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);

  /// Menghitung apakah versi saat ini sudah yang terbaru
  static Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final config = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('global')
          .get();

      if (!config.exists) return;

      final latestVersion = config.data()?['latestVersion'] ?? currentVersion;
      final minVersion = config.data()?['minVersion'] ?? currentVersion;
      final downloadUrl = config.data()?['downloadUrl'] ?? '';
      final isForceUpdate = config.data()?['isForceUpdate'] ?? false;

      if (_isVersionLower(currentVersion, latestVersion) &&
          downloadUrl.isNotEmpty) {
        if (context.mounted) {
          _showUpdateDialog(context, latestVersion, downloadUrl,
              isForce:
                  isForceUpdate || _isVersionLower(currentVersion, minVersion));
        }
      }
    } catch (e) {
      debugPrint('Check update failed: $e');
    }
  }

  static bool _isVersionLower(String current, String latest) {
    if (current == latest) return false;
    List<int> c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> l = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < c.length && i < l.length; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return l.length > c.length;
  }

  /// Memulai proses download & install APK
  static Future<void> startUpdate(String url) async {
    if (isDownloading.value) return;

    try {
      // 1. Request izin install dari sumber tak dikenal (Khusus Android)
      if (Platform.isAndroid) {
        var status = await Permission.requestInstallPackages.request();
        if (!status.isGranted) {
          debugPrint('Permission denied for install packages');
          return;
        }
      }

      isDownloading.value = true;
      downloadProgress.value = 0;

      final directory = await getExternalStorageDirectory();
      final savePath = '${directory!.path}/update_duit_gweh.apk';

      final dio = Dio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          }
        },
      );

      isDownloading.value = false;

      // 2. Buka Installer
      final result = await OpenFile.open(savePath);
      debugPrint('Install triggered: ${result.message}');
    } catch (e) {
      isDownloading.value = false;
      debugPrint('Update failed: $e');
    }
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String url,
      {bool isForce = false}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: '',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: isDownloading,
                    builder: (context, downloading, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (isForce ? Colors.red : Colors.blue)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isForce
                                  ? Icons.warning_amber_rounded
                                  : Icons.update_rounded,
                              color: isForce ? Colors.red : Colors.blue,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isForce
                                ? 'Pembaruan Wajib!'
                                : 'Versi $version Tersedia!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            downloading
                                ? 'Sedang mengunduh pembaruan. Silakan tunggu sebentar...'
                                : isForce
                                    ? 'Versi saat ini sudah tidak didukung. Silakan perbarui aplikasi ke versi $version untuk tetap bisa menggunakan My Duit Gweh.'
                                    : 'Ada fitur baru nih! Yuk update aplikasi kamu ke versi terbaru untuk pengalaman yang lebih lancar.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          if (downloading)
                            ValueListenableBuilder<double>(
                                valueListenable: downloadProgress,
                                builder: (context, progress, child) {
                                  return Column(
                                    children: [
                                      LinearProgressIndicator(
                                        value: progress,
                                        backgroundColor:
                                            Colors.blue.withOpacity(0.1),
                                        valueColor:
                                            const AlwaysStoppedAnimation<Color>(
                                                Colors.blue),
                                        borderRadius: BorderRadius.circular(10),
                                        minHeight: 8,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${(progress * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  );
                                })
                          else
                            Row(
                              children: [
                                if (!isForce) ...[
                                  Expanded(
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(
                                        'Nanti Saja',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => startUpdate(url),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isForce ? Colors.red : Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: Text(
                                      isForce ? 'PERBARUI' : 'UPDATE',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) => ScaleTransition(
        scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
        child: FadeTransition(opacity: anim1, child: child),
      ),
    );
  }
}
