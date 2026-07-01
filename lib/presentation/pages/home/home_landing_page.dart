import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/firebase_auth_provider.dart';

/// Temporary post-sign-in landing for Phase 1. Confirms the auth chain works by
/// showing the resolved member (name, role, assigned shops). Phase 1b replaces
/// this with the admin dashboard / shop entry, routed by role.
class HomeLandingPage extends ConsumerWidget {
  const HomeLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(authControllerProvider).member;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GreenChain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 48),
                const SizedBox(height: 16),
                Text('Signed in', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Name: ${member?.displayName ?? '-'}'),
                Text('Email: ${member?.email ?? '-'}'),
                Text('Role: ${member?.role.name ?? '-'}'),
                Text('Shops: ${member == null || member.shopIds.isEmpty ? 'all / none assigned' : member.shopIds.join(', ')}'),
                const SizedBox(height: 24),
                Text(
                  'This is a temporary landing. The admin dashboard and shop '
                  'entry screens arrive in the next phase.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
