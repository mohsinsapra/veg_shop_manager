import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/entry_providers.dart';
import '../providers/management_providers.dart';

/// A friendly, retryable error state (instead of a raw Firestore error string).
/// Wrapped in a scroll view so it also works inside a pull-to-refresh.
class DataErrorRetry extends StatelessWidget {
  final Future<void> Function() onRetry;
  final String message;
  const DataErrorRetry({
    super.key,
    required this.onRetry,
    this.message =
        "Couldn't load your data.\nCheck your connection, then pull down or tap Retry.",
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-fetches the shared data providers (used by pull-to-refresh and Retry).
Future<void> refreshAppData(WidgetRef ref) async {
  ref.invalidate(shopsProvider);
  ref.invalidate(catalogProvider);
  ref.invalidate(openCycleProvider);
  ref.invalidate(openCycleEntriesProvider);
  try {
    await Future.wait([
      ref.read(shopsProvider.future),
      ref.read(catalogProvider.future),
    ]);
  } catch (_) {
    // Errors surface through the watched providers' own error state.
  }
}
