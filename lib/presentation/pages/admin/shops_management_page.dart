import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/management_providers.dart';

class ShopsManagementPage extends ConsumerWidget {
  const ShopsManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(shopsProvider);
    return Scaffold(
      body: shopsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shops) => ListView(
          children: [
            for (final shop in shops)
              ListTile(
                leading: CircleAvatar(child: Text(shop.code)),
                title: Text(shop.name),
                subtitle: Text('Code: ${shop.code}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: shop.active,
                      onChanged: (v) =>
                          ref.read(shopRepositoryProvider).setActive(shop.id, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, ref, shop),
                    ),
                  ],
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

  void _showEditDialog(BuildContext context, WidgetRef ref, ShopEntity? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Shop' : 'Edit Shop'),
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
                controller: codeCtrl,
                decoration: const InputDecoration(
                    labelText: 'Code (grid column, e.g. D)'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a code' : null,
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
