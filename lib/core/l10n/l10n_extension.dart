import 'package:flutter/widgets.dart';
import 'package:veg_shop_manager/l10n/app_localizations.dart';

/// Concise access to generated translations: `context.l10n.someKey`.
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
