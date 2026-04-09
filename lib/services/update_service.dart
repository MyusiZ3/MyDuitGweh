import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/ui_helper.dart';
import '../utils/app_theme.dart';

class UpdateService {
  static final ValueNotifier<double> downloadProgress = ValueNotifier(0);
  static final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  static bool _isUpdateDialogOpen = false;
  static BuildContext? _currentDialogContext;
  static bool _sessionUpdateSkipped = false;
  static String? _skippedVersion;

  /// Cek update secara manual dari UI (misal: About Screen)
  static Future<void> checkUpdateManual(BuildContext context) async {
    UIHelper.showLoadingDialog(context, message: 'Memeriksa pembaruan...');
    
    try {
      final doc = await FirebaseFirestore.instance.collection('app_config').doc('global').get();
      if (!doc.exists) {
        if (context.mounted) {
          Navigator.pop(context); // close loading
          UIHelper.showInfoSnackBar(context, 'Gagal terhubung ke server.');
        }
        return;
      }

      final config = doc.data()!;
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final latestVersion = config['latestVersion'] ?? currentVersion;
      final downloadUrl = config['downloadUrl'] ?? '';

      if (context.mounted) {
        Navigator.pop(context); // close loading
        
        if (_isVersionLower(currentVersion, latestVersion) && downloadUrl.isNotEmpty) {
          final minVersion = config['minVersion'] ?? currentVersion;
          final isForceUpdate = config['isForceUpdate'] ?? false;
          final bool isForce = isForceUpdate || _isVersionLower(currentVersion, minVersion);
          
          _showUpdateDialog(context, latestVersion, downloadUrl, isForce: isForce);
        } else {
          UIHelper.showSuccessSnackBar(context, 'Aplikasi sudah versi terbaru! ✨');
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        UIHelper.showErrorSnackBar(context, 'Terjadi kesalahan saat mengecek update.');
      }
    }
  }

  /// Fungsi sinkronisasi real-time untuk menutup/membuka dialog berdasarkan data Firestore
  static void syncUpdateDialog(BuildContext context, Map<String, dynamic> config) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final latestVersion = config['latestVersion'] ?? currentVersion;
      final minVersion = config['minVersion'] ?? currentVersion;
      final downloadUrl = config['downloadUrl'] ?? '';
      final isForceUpdate = config['isForceUpdate'] ?? false;

      final bool isForce = isForceUpdate || _isVersionLower(currentVersion, minVersion);

      final isUpdateNeeded = _isVersionLower(currentVersion, latestVersion);

      if (isUpdateNeeded && downloadUrl.isNotEmpty) {
        // Jangan tampilkan jika sudah di-skip di sesi ini untuk versi yang sama
        // kecuali jika itu FORCE update
        if (_sessionUpdateSkipped && _skippedVersion == latestVersion && !isForce) {
          debugPrint('--- UpdateService: Update skipped for this session.');
          return;
        }

        if (!_isUpdateDialogOpen) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, downloadUrl, isForce: isForce);
          }
        }
      } else {
        // Jika update tidak lagi dibutuhkan (admin menarik/disable update), tutup dialog bila sedang terbuka
        if (_isUpdateDialogOpen && _currentDialogContext != null && _currentDialogContext!.mounted) {
          Navigator.of(_currentDialogContext!).pop();
          _isUpdateDialogOpen = false;
          _currentDialogContext = null;
        }
      }
    } catch (e) {
      debugPrint('Sync update failed: $e');
    }
  }

  /// Menghitung apakah versi saat ini sudah yang terbaru (Legacy Check)
  static bool _isVersionLower(String current, String latest) {
    if (current == latest) return false;

    // Bersihkan versi dari build number (+...) untuk perbandingan dasar
    String cClean = current.split('+')[0];
    String lClean = latest.split('+')[0];

    List<String> cParts = cClean.split('.');
    List<String> lParts = lClean.split('.');

    for (int i = 0; i < 3; i++) {
      int cVal = i < cParts.length ? (int.tryParse(cParts[i]) ?? 0) : 0;
      int lVal = i < lParts.length ? (int.tryParse(lParts[i]) ?? 0) : 0;

      if (lVal > cVal) return true;
      if (lVal < cVal) return false;
    }

    // Jika versi dasar sama, cek build number jika ada
    if (current.contains('+') && latest.contains('+')) {
      int cBuild = int.tryParse(current.split('+')[1]) ?? 0;
      int lBuild = int.tryParse(latest.split('+')[1]) ?? 0;
      return lBuild > cBuild;
    } else if (latest.contains('+')) {
      // Latest punya build number, current tidak
      return true;
    }

    return false;
  }

  /// Memulai proses download & install APK
  static Future<void> startUpdate(BuildContext context, String url) async {
    if (isDownloading.value) return;

    try {
      if (!Platform.isAndroid) {
        UIHelper.showInfoSnackBar(context, 'Fitur install otomatis hanya tersedia di Android. Silakan unduh manual.');
        return;
      }

      var status = await Permission.requestInstallPackages.status;
      if (status.isDenied) {
        status = await Permission.requestInstallPackages.request();
      }

      if (!status.isGranted) {
        if (context.mounted) {
          UIHelper.showErrorSnackBar(context,
              'Izin diperlukan untuk menginstall aplikasi baru. Silakan berikan izin di pengaturan.');
          if (status.isPermanentlyDenied) {
            openAppSettings();
          }
        }
        return;
      }

      isDownloading.value = true;
      downloadProgress.value = 0;

      // Gunakan Temporary Directory agar lebih bersih dan aman di Android 11+
      final directory = await getTemporaryDirectory();
      final savePath = '${directory.path}/myduitgweh_update.apk';

      // Hapus file lama jika ada agar tidak konflik
      final oldFile = File(savePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      final dio = Dio();
      // Tambahkan cache breaker agar tidak mengambil file lama dari cache CDN
      final downloadUrl = url.contains('?') ? '$url&t=${DateTime.now().millisecondsSinceEpoch}' : '$url?t=${DateTime.now().millisecondsSinceEpoch}';
      
      await dio.download(
        downloadUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgress.value = received / total;
          } else {
            // Jika total tidak diketahui (-1), kirim nilai negatif sebagai sinyal indeterminate
            // atau kirim nilai received dalam bentuk format tertentu
            downloadProgress.value = -1.0; 
          }
        },
      );

      isDownloading.value = false;

      // 2. Buka Installer secara langsung dengan MIME type yang spesifik
      final result = await OpenFile.open(
        savePath,
        type: 'application/vnd.android.package-archive',
      );

      if (result.type != ResultType.done) {
        if (context.mounted) {
          UIHelper.showErrorSnackBar(
              context, 'Gagal membuka instalasi: ${result.message}');
        }
      }
    } catch (e) {
      isDownloading.value = false;
      if (context.mounted) {
        UIHelper.showErrorSnackBar(context,
            'Gagal mengunduh pembaruan. Pastikan koneksi internet stabil.');
      }
      debugPrint('Update failed: $e');
    }
  }

  static void _showUpdateDialog(
      BuildContext context, String version, String url,
      {bool isForce = false}) {
    _isUpdateDialogOpen = true;
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
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          SizedBox(
                                            height: 12,
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: LinearProgressIndicator(
                                                value: progress < 0 ? null : progress, // null membuat loading jalan terus (indeterminate)
                                                backgroundColor: AppColors
                                                    .primary
                                                    .withOpacity(0.1),
                                                valueColor:
                                                    const AlwaysStoppedAnimation<
                                                            Color>(
                                                        AppColors.primary),
                                                minHeight: 12,
                                              ),
                                            ),
                                          ),
                                          // Shimmer reflection effect on the progress bar could be here
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            progress < 0 ? 'MENGUNDUH...' : 'PERSENTASE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              progress < 0 ? '...' : '${(progress * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                })
                          else
                            Row(
                              children: [
                                if (!isForce) ...[
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => Navigator.pop(context),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color:
                                                  Colors.grey.withOpacity(0.2)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'NANTI SAJA',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontWeight: FontWeight.w900,
                                              fontSize: 12,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: InkWell(
                                    onTap: () => startUpdate(context, url),
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isForce
                                            ? AppColors.expense
                                            : AppColors.primary,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isForce
                                                    ? AppColors.expense
                                                    : AppColors.primary)
                                                .withOpacity(0.3),
                                            blurRadius: 15,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          isForce ? 'PERBARUI' : 'UPDATE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
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
      transitionBuilder: (context, anim1, anim2, child) {
        _currentDialogContext = context;
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    ).then((_) {
      _isUpdateDialogOpen = false;
      _currentDialogContext = null;
    });
  }
}
