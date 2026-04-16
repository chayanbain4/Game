import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ForceUpdateScreen extends StatefulWidget {
  final String message;
  final String apkUrl;

  const ForceUpdateScreen({
    super.key,
    required this.message,
    required this.apkUrl,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  bool _downloading = false;
  bool _downloaded = false;
  double _progress = 0;
  String _status = '';
  String? _savedPath;

  Future<void> _downloadAndInstall() async {
    // If already downloaded, just open installer
    if (_downloaded && _savedPath != null) {
      await OpenFilex.open(_savedPath!);
      return;
    }

    // Step 1: Request install packages permission (Android 8+)
    final installPerm = await Permission.requestInstallPackages.request();
    if (!installPerm.isGranted) {
      if (mounted) {
        setState(() => _status = 'Please allow "Install unknown apps" in settings.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please allow installing unknown apps in settings'),
            duration: Duration(seconds: 3),
          ),
        );
      }
      await openAppSettings();
      return;
    }

    // Step 2: Start download
    setState(() {
      _downloading = true;
      _downloaded = false;
      _progress = 0;
      _status = 'Starting download...';
    });

    try {
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir!.path}/ludo-update.apk';

      // Delete old file if exists
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(minutes: 10);

      await dio.download(
        widget.apkUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() {
              _progress = received / total;
              _status =
                  '${(_progress * 100).toStringAsFixed(0)}%  '
                  '(${(received / 1024 / 1024).toStringAsFixed(1)} MB'
                  ' / ${(total / 1024 / 1024).toStringAsFixed(1)} MB)';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _downloading = false;
          _downloaded = true;
          _savedPath = savePath;
          _status = 'Download complete! Opening installer...';
        });
      }

      // Step 3: Open APK installer
      final result = await OpenFilex.open(savePath);
      debugPrint('OpenFilex result: ${result.message}');

    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() {
          _downloading = false;
          _downloaded = false;
          _status = 'Download failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset(
                    'assets/image/logo.png',
                    width: 160,
                    height: 160,
                  ),
                  const SizedBox(height: 24),

                  // Title
                  const Text(
                    'Update Required',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Server message
                  Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Progress bar
                  if (_downloading || _downloaded) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 12,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 13,
                        color: _downloaded ? Colors.green : Colors.black54,
                        fontWeight: _downloaded
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Error status (when not downloading)
                  if (!_downloading && !_downloaded && _status.isNotEmpty) ...[
                    Text(
                      _status,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _downloading ? null : _downloadAndInstall,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _downloading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Downloading...',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            )
                          : Text(
                              _downloaded ? 'Install Now' : 'Update Now',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'You must update the app to continue.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black38,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}