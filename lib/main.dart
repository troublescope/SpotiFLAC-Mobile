import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/app.dart';
import 'package:spotiflac_android/providers/download_queue_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(
      child: const _EagerInitialization(
        child: SpotiFLACApp(),
      ),
    ),
  );
}

/// Widget to eagerly initialize providers that need to load data on startup
class _EagerInitialization extends ConsumerWidget {
  const _EagerInitialization({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize download history provider to load from storage
    ref.watch(downloadHistoryProvider);
    return child;
  }
}
