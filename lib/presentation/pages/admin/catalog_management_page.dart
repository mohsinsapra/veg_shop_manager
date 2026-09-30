import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/utils/qty_format.dart';
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
                    const Icon(
                      Icons.drag_indicator,
                      size: 18,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.adminCatalogReorderHint,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
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
                        child: item.imageUrl.isEmpty
                            ? const Icon(Icons.drag_handle)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.drag_handle),
                                  const SizedBox(width: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.network(
                                      item.imageUrl,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      title: Text(item.name),
                      subtitle: Text(item.packSizes.isEmpty
                          ? item.category
                          : '${item.category} · ${_sizesHint(item)}'),
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
                            onPressed: () =>
                                _showEditDialog(context, ref, item),
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

  /// Subtle catalog-list hint for a sized item, e.g. "5/10 kg".
  String _sizesHint(CatalogItemEntity item) {
    final sizes = [...item.packSizes]..sort();
    final unit = item.unit.isEmpty ? 'kg' : item.unit;
    return '${sizes.map(fmtQty).join('/')} $unit';
  }

  void _reorder(
    WidgetRef ref,
    List<CatalogItemEntity> items,
    int oldIndex,
    int newIndex,
  ) {
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
    BuildContext context,
    WidgetRef ref,
    CatalogItemEntity? existing,
  ) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final catCtrl = TextEditingController(text: existing?.category ?? '');
    final imageUrlCtrl = TextEditingController(text: existing?.imageUrl ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? '');
    final sizeInputCtrl = TextEditingController();
    final packSizes = [...?existing?.packSizes];
    String? sizeError;
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? context.l10n.adminCatalogAddTitle
              : context.l10n.adminCatalogEditTitle,
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.adminCatalogNameLabel,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.validationEnterName
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: catCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.adminCatalogCategoryLabel,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.l10n.adminCatalogCategoryRequired
                    : null,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setState) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: imageUrlCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.catalogImageUrlLabel,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (imageUrlCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Image.network(
                        imageUrlCtrl.text.trim(),
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: unitCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.catalogUnitLabel,
                        hintText: 'kg / caja / und',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        context.l10n.catalogPackSizesLabel,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (packSizes.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final size in packSizes)
                            InputChip(
                              label: Text(unitCtrl.text.trim().isEmpty
                                  ? fmtQty(size)
                                  : '${fmtQty(size)} ${unitCtrl.text.trim()}'),
                              onDeleted: () =>
                                  setState(() => packSizes.remove(size)),
                            ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: sizeInputCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: context.l10n.catalogPackSizeHint,
                              errorText: sizeError,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            final raw =
                                sizeInputCtrl.text.trim().replaceAll(',', '.');
                            final value = double.tryParse(raw);
                            setState(() {
                              if (value == null || value <= 0) {
                                sizeError =
                                    context.l10n.catalogPackSizeInvalid;
                              } else if (packSizes.contains(value)) {
                                sizeError =
                                    context.l10n.catalogPackSizeDuplicate;
                              } else {
                                packSizes.add(value);
                                packSizes.sort();
                                sizeInputCtrl.clear();
                                sizeError = null;
                              }
                            });
                          },
                          child: Text(context.l10n.catalogPackSizeAdd),
                        ),
                      ],
                    ),
                  ],
                ),
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
                imageUrl: imageUrlCtrl.text.trim(),
                unit: unitCtrl.text.trim(),
                packSizes: [...packSizes]..sort(),
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
