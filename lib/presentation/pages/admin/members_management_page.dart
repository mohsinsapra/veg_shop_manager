import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
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
                subtitle: Text(
                  '${m.email} • ${m.role == MemberRole.admin ? context.l10n.adminMembersRoleAdmin : context.l10n.adminMembersRoleMember}'
                  '${m.shopIds.isEmpty ? '' : ' ${context.l10n.adminMembersShopsCount(m.shopIds.length)}'}',
                ),
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
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Theme.of(context).colorScheme.error,
                      tooltip: context.l10n.delete,
                      // An admin cannot delete their own account: losing your
                      // access mid-session would lock you out of undoing it.
                      onPressed:
                          m.id == ref.watch(authControllerProvider).member?.id
                          ? null
                          : () => _confirmDelete(context, ref, m),
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

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MemberEntity m,
  ) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.adminMembersDeleteConfirmTitle),
        content: Text(
          '${m.displayName} (${m.email})\n\n'
          '${l10n.adminMembersDeleteConfirmBody}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(memberRepositoryProvider).delete(m.id);
  }

  void _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    MemberEntity? existing,
  ) {
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
          title: Text(
            existing == null
                ? context.l10n.adminMembersAddTitle
                : context.l10n.adminMembersEditTitle,
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: emailCtrl,
                    enabled: existing == null,
                    decoration: InputDecoration(
                      labelText: context.l10n.adminMembersEmailLabel,
                    ),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? context.l10n.adminMembersEmailInvalid
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: context.l10n.adminMembersNameLabel,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.validationEnterName
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<MemberRole>(
                    initialValue: role,
                    decoration: InputDecoration(
                      labelText: context.l10n.adminMembersRoleLabel,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: MemberRole.member,
                        child: Text(context.l10n.adminMembersRoleMember),
                      ),
                      DropdownMenuItem(
                        value: MemberRole.admin,
                        child: Text(context.l10n.adminMembersRoleAdmin),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => role = v ?? MemberRole.member),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(context.l10n.adminMembersShopsHeading),
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
              child: Text(context.l10n.cancel),
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
              child: Text(context.l10n.save),
            ),
          ],
        ),
      ),
    );
  }
}
