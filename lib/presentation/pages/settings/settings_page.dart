import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../providers/locale_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              context.l10n.language,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          RadioListTile<Locale>(
            value: const Locale('es'),
            groupValue: locale,
            onChanged: (v) => controller.setLocale(v!),
            title: Text(context.l10n.languageSpanish),
          ),
          RadioListTile<Locale>(
            value: const Locale('en'),
            groupValue: locale,
            onChanged: (v) => controller.setLocale(v!),
            title: Text(context.l10n.languageEnglish),
          ),
        ],
      ),
    );
  }
}
