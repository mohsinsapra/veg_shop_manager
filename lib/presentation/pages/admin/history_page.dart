import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../domain/entities/entry_entity.dart';
import '../../providers/entry_providers.dart';

/// Completed shopping cycles, most recent first. Tapping a cycle lists what
/// was bought (kept for future bought-vs-sold analytics).
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(completedCyclesProvider);
    final df = DateFormat('EEE, d MMM yyyy • HH:mm');

    return cyclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cycles) {
        if (cycles.isEmpty) {
          return const Center(child: Text('No completed lists yet.'));
        }
        return ListView(
          children: [
            for (final c in cycles)
              FutureBuilder<List<EntryEntity>>(
                future: ref.read(entryRepositoryProvider).getByCycle(c.id),
                builder: (context, snap) {
                  final entries = snap.data ?? const <EntryEntity>[];
                  final units = entries.fold<int>(0, (s, e) => s + e.quantity);
                  return Card(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ExpansionTile(
                      leading: const Icon(Icons.history),
                      title: Text(df.format((c.completedAt ?? c.openedAt).toLocal())),
                      subtitle: Text('${entries.length} items · $units units'),
                      children: [
                        for (final e in entries)
                          ListTile(
                            dense: true,
                            title: Text(e.itemName),
                            trailing: Text('${e.quantity}'),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
