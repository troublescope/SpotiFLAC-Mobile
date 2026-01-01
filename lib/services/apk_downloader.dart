import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

typedef ProgressCallback = void Function(int received, int total);

class ApkDownloader {
  static Future<String?> downloadApk({
    required String url,
    required String version,
    ProgressCallback? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        print('[ApkDownloader] Failed to download: ${response.statusCode}');
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      
      // Get download directory
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        print('[ApkDownloader] Could not get storage directory');
        return null;
      }

      final filePath = '${dir.path}/SpotiFLAC-$version.apk';
      final file = File(filePath);
      
      // Delete if exists
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, contentLength);
      }

      await sink.close();
      client.close();

      print('[ApkDownloader] Downloaded to: $filePath');
      return filePath;
    } catch (e) {
      print('[ApkDownloader] Error: $e');
      return null;
    }
  }

  static Future<void> installApk(String filePath) async {
    try {
      final result = await OpenFilex.open(filePath);
      print('[ApkDownloader] Open result: ${result.type} - ${result.message}');
    } catch (e) {
      print('[ApkDownloader] Install error: $e');
    }
  }
}
