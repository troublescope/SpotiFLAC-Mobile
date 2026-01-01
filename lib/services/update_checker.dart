import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:spotiflac_android/constants/app_info.dart';

class UpdateInfo {
  final String version;
  final String changelog;
  final String downloadUrl;
  final String? apkDownloadUrl; // Direct APK download URL
  final DateTime publishedAt;

  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    this.apkDownloadUrl,
    required this.publishedAt,
  });
}

class UpdateChecker {
  static const String _apiUrl = 'https://api.github.com/repos/${AppInfo.githubRepo}/releases/latest';

  /// Get device CPU architecture
  static Future<String> _getDeviceArch() async {
    if (!Platform.isAndroid) return 'unknown';
    
    try {
      // Read CPU info from /proc/cpuinfo
      final cpuInfo = await File('/proc/cpuinfo').readAsString();
      
      // Check for 64-bit indicators
      if (cpuInfo.contains('AArch64') || cpuInfo.contains('aarch64')) {
        return 'arm64';
      }
      
      // Check architecture from uname
      final result = await Process.run('uname', ['-m']);
      final arch = result.stdout.toString().trim().toLowerCase();
      
      if (arch.contains('aarch64') || arch.contains('arm64')) {
        return 'arm64';
      } else if (arch.contains('armv7') || arch.contains('arm')) {
        return 'arm32';
      } else if (arch.contains('x86_64')) {
        return 'x86_64';
      } else if (arch.contains('x86') || arch.contains('i686')) {
        return 'x86';
      }
      
      return 'arm64'; // Default to arm64 for modern devices
    } catch (e) {
      print('[UpdateChecker] Error detecting arch: $e');
      return 'arm64'; // Default fallback
    }
  }

  /// Check for updates from GitHub releases
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('[UpdateChecker] GitHub API returned ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');
      
      if (!_isNewerVersion(latestVersion, AppInfo.version)) {
        print('[UpdateChecker] No update available (current: ${AppInfo.version}, latest: $latestVersion)');
        return null;
      }

      // Get changelog from release body
      final body = data['body'] as String? ?? 'No changelog available';
      final htmlUrl = data['html_url'] as String? ?? '${AppInfo.githubUrl}/releases';
      final publishedAt = DateTime.tryParse(data['published_at'] as String? ?? '') ?? DateTime.now();

      // Find APK download URL from assets based on device architecture
      final deviceArch = await _getDeviceArch();
      print('[UpdateChecker] Device architecture: $deviceArch');
      
      String? arm64Url;
      String? arm32Url;
      String? universalUrl;
      
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          final downloadUrl = asset['browser_download_url'] as String?;
          if (name.contains('arm64') || name.contains('v8a')) {
            arm64Url = downloadUrl;
          } else if (name.contains('arm32') || name.contains('v7a') || name.contains('armeabi')) {
            arm32Url = downloadUrl;
          } else if (name.contains('universal')) {
            universalUrl = downloadUrl;
          }
        }
      }
      
      // Select APK based on device architecture
      String? apkUrl;
      if (deviceArch == 'arm64') {
        apkUrl = arm64Url ?? universalUrl ?? arm32Url;
      } else if (deviceArch == 'arm32') {
        apkUrl = arm32Url ?? universalUrl;
      } else {
        apkUrl = universalUrl ?? arm64Url ?? arm32Url;
      }

      print('[UpdateChecker] Update available: $latestVersion, APK URL: $apkUrl');
      
      return UpdateInfo(
        version: latestVersion,
        changelog: body,
        downloadUrl: htmlUrl,
        apkDownloadUrl: apkUrl,
        publishedAt: publishedAt,
      );
    } catch (e) {
      print('[UpdateChecker] Error checking for updates: $e');
      return null;
    }
  }

  /// Compare version strings (e.g., "1.1.1" vs "1.1.0")
  static bool _isNewerVersion(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      // Pad with zeros if needed
      while (latestParts.length < 3) {
        latestParts.add(0);
      }
      while (currentParts.length < 3) {
        currentParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false; // Same version
    } catch (e) {
      return false;
    }
  }

  static String get currentVersion => AppInfo.version;
}
