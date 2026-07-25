import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';

class ShopsManagementPage extends ConsumerWidget {
  const ShopsManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider);
    return Scaffold(
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
        data: (shops) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  const Icon(Icons.drag_indicator, size: 18, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.l10n.adminShopsReorderHint,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.sort_by_alpha),
                    tooltip: context.l10n.adminShopsSortAZ,
                    onPressed: () => _sortAlphabetically(ref, shops),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: shops.length,
                onReorder: (oldIndex, newIndex) =>
                    _reorder(ref, shops, oldIndex, newIndex),
                itemBuilder: (context, i) {
                  final shop = shops[i];
                  return ListTile(
                    key: ValueKey(shop.id),
                    dense: true,
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    title: Text(shop.name),
                    subtitle: Text(context.l10n.adminShopsCodeSubtitle(shop.code)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: shop.active,
                          onChanged: (v) => ref
                              .read(shopRepositoryProvider)
                              .setActive(shop.id, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showEditDialog(context, ref, shop),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _reorder(
      WidgetRef ref, List<ShopEntity> shops, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final list = [...shops];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    // Renormalize sortOrder to the new positions; persist only what changed.
    final changes = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) changes[list[i].id] = i;
    }
    ref.read(shopRepositoryProvider).setSortOrders(changes);
  }

  void _sortAlphabetically(WidgetRef ref, List<ShopEntity> shops) {
    final list = [...shops]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final changes = <String, int>{};
    for (var i = 0; i < list.length; i++) {
      if (list[i].sortOrder != i) changes[list[i].id] = i;
    }
    ref.read(shopRepositoryProvider).setSortOrders(changes);
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ShopEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null
            ? context.l10n.adminShopsAddTitle
            : context.l10n.adminShopsEditTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration:
                    InputDecoration(labelText: context.l10n.adminShopsNameLabel),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.validationEnterName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: codeCtrl,
                decoration: InputDecoration(
                    labelText: context.l10n.adminShopsCodeFieldLabel),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.adminShopsCodeRequired
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
              final repo = ref.read(shopRepositoryProvider);
              final shop = ShopEntity(
                id: existing?.id ?? const Uuid().v4(),
                name: nameCtrl.text.trim(),
                code: codeCtrl.text.trim().toUpperCase(),
                sortOrder: existing?.sortOrder ?? 9999,
                active: existing?.active ?? true,
              );
              await repo.upsert(shop);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
  }
}
