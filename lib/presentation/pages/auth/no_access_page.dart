import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../providers/firebase_auth_provider.dart';

class NoAccessPage extends ConsumerWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(context.l10n.noAccessMessage, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              child: Text(context.l10n.noAccessSignOutButton),
            ),
          ],
        ),
      ),
    );
  }
}
