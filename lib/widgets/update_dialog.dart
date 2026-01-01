import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:spotiflac_android/constants/app_info.dart';
import 'package:spotiflac_android/services/update_checker.dart';
import 'package:spotiflac_android/services/apk_downloader.dart';
import 'package:spotiflac_android/services/notification_service.dart';

class UpdateDialog extends StatefulWidget {
  final UpdateInfo updateInfo;
  final VoidCallback onDismiss;
  final VoidCallback onDisableUpdates;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    required this.onDismiss,
    required this.onDisableUpdates,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0;
  String _statusText = '';

  Future<void> _downloadAndInstall() async {
    final apkUrl = widget.updateInfo.apkDownloadUrl;
    
    // If no direct APK URL, open release page
    if (apkUrl == null) {
      final uri = Uri.parse(widget.updateInfo.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (mounted) Navigator.pop(context);
      return;
    }

    setState(() {
      _isDownloading = true;
      _progress = 0;
      _statusText = 'Starting download...';
    });

    final notificationService = NotificationService();
    
    final filePath = await ApkDownloader.downloadApk(
      url: apkUrl,
      version: widget.updateInfo.version,
      onProgress: (received, total) {
        if (mounted) {
          setState(() {
            _progress = total > 0 ? received / total : 0;
            final receivedMB = (received / 1024 / 1024).toStringAsFixed(1);
            final totalMB = (total / 1024 / 1024).toStringAsFixed(1);
            _statusText = '$receivedMB / $totalMB MB';
          });
        }
        // Update notification
        notificationService.showUpdateDownloadProgress(
          version: widget.updateInfo.version,
          received: received,
          total: total,
        );
      },
    );

    if (filePath != null) {
      await notificationService.showUpdateDownloadComplete(
        version: widget.updateInfo.version,
      );
      
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Open APK for installation
      await ApkDownloader.installApk(filePath);
    } else {
      await notificationService.showUpdateDownloadFailed();
      
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _statusText = 'Download failed';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download update')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Update Available'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'v${AppInfo.version}',
                    style: TextStyle(color: colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 16, color: colorScheme.onPrimaryContainer),
                  const SizedBox(width: 8),
                  Text(
                    'v${widget.updateInfo.version}',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Changelog header
            Text(
              'What\'s New:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Changelog content (scrollable) - hide when downloading
            if (!_isDownloading)
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _formatChangelog(widget.updateInfo.changelog),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ),
            
            // Download progress
            if (_isDownloading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _statusText,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: _isDownloading
          ? [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ]
          : [
              // Don't remind again button
              TextButton(
                onPressed: () {
                  widget.onDisableUpdates();
                  Navigator.pop(context);
                },
                child: Text(
                  'Don\'t remind',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ),
              // Later button
              TextButton(
                onPressed: () {
                  widget.onDismiss();
                  Navigator.pop(context);
                },
                child: const Text('Later'),
              ),
              // Download button
              FilledButton(
                onPressed: _downloadAndInstall,
                child: const Text('Install'),
              ),
            ],
    );
  }

  /// Format changelog - clean up markdown and extract relevant content
  String _formatChangelog(String changelog) {
    // Try to extract just the changelog section (between "What's New" and "Downloads" or "---")
    var content = changelog;
    
    // Find content after "What's New" header
    final whatsNewMatch = RegExp(r"###?\s*What'?s\s*New\s*\n", caseSensitive: false).firstMatch(content);
    if (whatsNewMatch != null) {
      content = content.substring(whatsNewMatch.end);
    }
    
    // Cut off at "Downloads" section or horizontal rule
    final cutoffMatch = RegExp(r'\n---|\n###?\s*Downloads', caseSensitive: false).firstMatch(content);
    if (cutoffMatch != null) {
      content = content.substring(0, cutoffMatch.start);
    }
    
    // Process line by line for better formatting
    final lines = content.split('\n');
    final formattedLines = <String>[];
    String? currentSection;
    
    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;
      
      // Check if it's a section header (### Added, ### Fixed, etc.)
      final sectionMatch = RegExp(r'^#{1,3}\s*(.+)$').firstMatch(line);
      if (sectionMatch != null) {
        currentSection = sectionMatch.group(1)?.trim();
        if (currentSection != null && currentSection.isNotEmpty) {
          if (formattedLines.isNotEmpty) formattedLines.add('');
          formattedLines.add('$currentSection:');
        }
        continue;
      }
      
      // Check if it's a list item
      final listMatch = RegExp(r'^[-*]\s+(.+)$').firstMatch(line);
      if (listMatch != null) {
        var itemText = listMatch.group(1) ?? '';
        // Remove bold markdown
        itemText = itemText.replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'), 
          (m) => m.group(1) ?? ''
        );
        // Remove code markdown
        itemText = itemText.replaceAllMapped(
          RegExp(r'`([^`]+)`'), 
          (m) => m.group(1) ?? ''
        );
        formattedLines.add('• $itemText');
        continue;
      }
      
      // Check if it's a sub-item (indented list)
      final subListMatch = RegExp(r'^\s+[-*]\s+(.+)$').firstMatch(line);
      if (subListMatch != null) {
        var itemText = subListMatch.group(1) ?? '';
        itemText = itemText.replaceAllMapped(
          RegExp(r'\*\*([^*]+)\*\*'), 
          (m) => m.group(1) ?? ''
        );
        formattedLines.add('  - $itemText');
        continue;
      }
    }
    
    var formatted = formattedLines.join('\n').trim();
    
    // Limit length
    if (formatted.length > 2000) {
      formatted = '${formatted.substring(0, 2000)}...';
    }
    
    return formatted.isEmpty ? 'See release notes for details.' : formatted;
  }
}

/// Show update dialog
Future<void> showUpdateDialog(
  BuildContext context, {
  required UpdateInfo updateInfo,
  required VoidCallback onDisableUpdates,
}) async {
  return showDialog(
    context: context,
    builder: (context) => UpdateDialog(
      updateInfo: updateInfo,
      onDismiss: () {},
      onDisableUpdates: onDisableUpdates,
    ),
  );
}
