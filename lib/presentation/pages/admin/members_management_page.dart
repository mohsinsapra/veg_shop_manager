import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/member_entity.dart';
import '../../../domain/entities/shop_entity.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/management_providers.dart';
import '../../widgets/data_error_retry.dart';

class MembersManagementPage extends ConsumerWidget {
  const MembersManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(membersProvider);
    return Scaffold(
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DataErrorRetry(onRetry: () => refreshAppData(ref)),
        data: (members) => ListView(
          children: [
            for (final m in members)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(m.isAdmin ? Icons.shield : Icons.person),
                ),
                title: Text(m.displayName),
                subtitle: Text('${m.email} • ${m.role.name}'
                    '${m.shopIds.isEmpty ? '' : ' • ${m.shopIds.length} shop(s)'}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: m.active,
                      onChanged: (v) =>
                          ref.read(memberRepositoryProvider).setActive(m.id, v),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditDialog(context, ref, m),
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

  void _showEditDialog(BuildContext context, WidgetRef ref, MemberEntity? existing) {
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    var role = existing?.role ?? MemberRole.member;
    final selectedShops = {...?existing?.shopIds};
    final formKey = GlobalKey<FormState>();
    final shops = ref.read(shopsProvider).valueOrNull ?? const <ShopEntity>[];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add Member' : 'Edit Member'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    enabled: existing == null,
                    decoration: const InputDecoration(labelText: 'Google email'),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Display name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  DropdownButtonFormField<MemberRole>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: const [
                      DropdownMenuItem(
                          value: MemberRole.member, child: Text('member')),
                      DropdownMenuItem(
                          value: MemberRole.admin, child: Text('admin')),
                    ],
                    onChanged: (v) =>
                        setState(() => role = v ?? MemberRole.member),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Shops'),
                  ),
                  for (final s in shops)
                    CheckboxListTile(
                      dense: true,
                      title: Text('${s.name} (${s.code})'),
                      value: selectedShops.contains(s.id),
                      onChanged: (checked) => setState(() {
                        if (checked == true) {
                          selectedShops.add(s.id);
                        } else {
                          selectedShops.remove(s.id);
                        }
                      }),
                    ),
                ],
              ),
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
                final email = emailCtrl.text.trim().toLowerCase();
                final member = MemberEntity(
                  id: existing?.id ?? email,
                  email: email,
                  displayName: nameCtrl.text.trim(),
                  role: role,
                  shopIds: selectedShops.toList(),
                  active: existing?.active ?? true,
                  uid: existing?.uid,
                );
                await ref.read(memberRepositoryProvider).upsert(member);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
