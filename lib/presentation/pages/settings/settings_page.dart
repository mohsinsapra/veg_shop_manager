import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../providers/locale_provider.dart';
import '../../providers/show_item_images_provider.dart';
import '../../providers/theme_mode_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final localeController = ref.read(localeProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final themeController = ref.read(themeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        children: [
          _sectionHeader(context, context.l10n.language),
          RadioListTile<Locale>(
            value: const Locale('es'),
            groupValue: locale,
            onChanged: (v) => localeController.setLocale(v!),
            title: Text(context.l10n.languageSpanish),
          ),
          RadioListTile<Locale>(
            value: const Locale('en'),
            groupValue: locale,
            onChanged: (v) => localeController.setLocale(v!),
            title: Text(context.l10n.languageEnglish),
          ),
          const Divider(),
          _sectionHeader(context, context.l10n.theme),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: themeMode,
            onChanged: (v) => themeController.setThemeMode(v!),
            title: Text(context.l10n.themeLight),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: themeMode,
            onChanged: (v) => themeController.setThemeMode(v!),
            title: Text(context.l10n.themeDark),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: themeMode,
            onChanged: (v) => themeController.setThemeMode(v!),
            title: Text(context.l10n.themeSystem),
          ),
          const Divider(),
          _sectionHeader(context, context.l10n.settingsDisplay),
          SwitchListTile(
            value: ref.watch(showItemImagesProvider),
            onChanged: (v) =>
                ref.read(showItemImagesProvider.notifier).set(v),
            title: Text(context.l10n.settingsShowImages),
            subtitle: Text(context.l10n.settingsShowImagesSubtitle),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
}
