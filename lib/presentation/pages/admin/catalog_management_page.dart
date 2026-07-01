import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../providers/management_providers.dart';

class CatalogManagementPage extends ConsumerWidget {
  const CatalogManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    return Scaffold(
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          final categories = <String, List<CatalogItemEntity>>{};
          for (final it in items) {
            categories.putIfAbsent(it.category, () => []).add(it);
          }
          return ListView(
            children: [
              for (final entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(entry.key,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                for (final item in entry.value)
                  ListTile(
                    dense: true,
                    title: Text(item.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: item.active,
                          onChanged: (v) => ref
                              .read(catalogRepositoryProvider)
                              .setActive(item.id, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, ref, item),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CatalogItemEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Item' : 'Edit Item'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              TextFormField(
                controller: catCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a category' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(catalogRepositoryProvider);
              final item = CatalogItemEntity(
                id: existing?.id ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                category: catCtrl.text.trim(),
                sortOrder: existing?.sortOrder ?? 9999,
                active: existing?.active ?? true,
              );
              await repo.upsert(item);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
