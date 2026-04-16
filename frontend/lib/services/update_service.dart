import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final bool forceUpdate;
  final String latestVersion;
  final String minRequiredVersion;
  final String message;
  final String apkUrl;

  AppUpdateInfo({
    required this.forceUpdate,
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.message,
    required this.apkUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      forceUpdate: json['forceUpdate'] ?? false,
      latestVersion: json['latestVersion'] ?? '',
      minRequiredVersion: json['minRequiredVersion'] ?? '',
      message: json['message'] ?? 'Update required',
      apkUrl: (json['apkUrl'] ?? '').toString().trim(),
    );
  }
}

class UpdateService {
  static const String baseUrl = bool.fromEnvironment('dart.vm.product')
      ? 'https://game.iwebgenics.com'
      : 'http://10.0.2.2:4017';

  static Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();

      final response = await http.get(
        Uri.parse('$baseUrl/api/app-version?platform=android&version=$currentVersion'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AppUpdateInfo.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static bool isVersionLower(String current, String minimum) {
    final currentParts = current.split('.').map(int.parse).toList();
    final minimumParts = minimum.split('.').map(int.parse).toList();

    final maxLength =
        currentParts.length > minimumParts.length
            ? currentParts.length
            : minimumParts.length;

    while (currentParts.length < maxLength) {
      currentParts.add(0);
    }

    while (minimumParts.length < maxLength) {
      minimumParts.add(0);
    }

    for (int i = 0; i < maxLength; i++) {
      if (currentParts[i] < minimumParts[i]) return true;
      if (currentParts[i] > minimumParts[i]) return false;
    }

    return false;
  }
}