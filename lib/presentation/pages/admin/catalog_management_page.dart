import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../domain/entities/catalog_item_entity.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';

class CatalogManagementPage extends ConsumerWidget {
  const CatalogManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(catalogProvider);
    return Scaffold(
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
        data: (items) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.adminCatalogReorderHint,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(ref, items, oldIndex, newIndex),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return ListTile(
                      key: ValueKey(item.id),
                      dense: true,
                      leading: ReorderableDragStartListener(
                        index: i,
                        child: const Icon(Icons.drag_handle),
                      ),
                      title: Text(item.name),
                      subtitle: Text(item.category),
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
                    );
                  },
                ),
              ),
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

  void _reorder(WidgetRef ref, List<CatalogItemEntity> items, int oldIndex,
      int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = [...items];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    // Renormalize sortOrder to the new positions; persist only what changed.
    final changes = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) changes[list[i].id] = i;
    }
    ref.read(catalogRepositoryProvider).setSortOrders(changes);
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, CatalogItemEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null
            ? context.l10n.adminCatalogAddTitle
            : context.l10n.adminCatalogEditTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.adminCatalogNameLabel),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.validationEnterName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: catCtrl,
                decoration: InputDecoration(
                    labelText: context.l10n.adminCatalogCategoryLabel),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.adminCatalogCategoryRequired
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel),
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
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
