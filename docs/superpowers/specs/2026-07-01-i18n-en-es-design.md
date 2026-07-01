# Design: Full English/Spanish i18n for GreenChain

Date: 2026-07-01
Status: Approved — ready for implementation planning

## Goal

Every user-facing UI string in the app is translatable, with complete
English and Spanish translations. A Settings page lets the user switch
language at runtime; the choice persists across restarts. No static,
hardcoded UI text remains anywhere in the presentation layer.

## Decisions (locked)

- **Product catalog names stay as-is.** The Spanish vegetable/fruit names in
  `app_constants.dart` (`Apio`, `Tomate Raf`, `Pimiento Italiano`, etc.) and
  any catalog data from Firestore are real product names and are NOT
  translated. They remain literal data.
- **Default language: Spanish (`es`).** App starts in Spanish on first run.
- **Switcher location: a dedicated Settings page**, reachable from every
  role's home screen (admin, shop, member) and the login/auth area.
- **Engine: official Flutter gen-l10n** (ARB files + `flutter_localizations`),
  producing a type-safe `AppLocalizations` accessed as `context.l10n.<key>`.
- App brand name "GreenChain" is not translated.

## Architecture

### 1. Localization engine & setup

- Add `flutter_localizations` (from the Flutter SDK) to `pubspec.yaml`.
  `intl` is already present.
- Enable Flutter's l10n codegen: add `generate: true` under `flutter:` in
  `pubspec.yaml`, and add an `l10n.yaml` at the project root:

  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppLocalizations
  nullable-getter: false
  ```

- Translation source files:
  - `lib/l10n/app_en.arb` — template (English), the source of keys.
  - `lib/l10n/app_es.arb` — Spanish translations, complete parity with the
    template.
- Codegen produces `AppLocalizations`. A small `BuildContext` extension
  (`lib/core/l10n/l10n_extension.dart`) exposes `context.l10n` →
  `AppLocalizations.of(context)` for concise call sites.
- Placeholders and plurals are expressed in ARB syntax (e.g.
  `"itemsCount": "{count, plural, =0{No items} =1{1 item} other{{count} items}}"`)
  so dynamic strings (counts, names, dates) are also fully localized.

### 2. Locale state & persistence

- **`localeProvider`** — a Riverpod `Notifier<Locale>` in
  `lib/presentation/providers/locale_provider.dart`.
  - Initial value: the persisted locale if present, else Spanish (`es`).
  - Exposes `setLocale(Locale)` which updates state AND persists the choice.
- **Persistence via existing `StorageService`.** Add two methods to the
  `StorageService` interface (implemented in both `HiveStorageService` and
  `SharedPreferencesStorageService`):
  - `Future<String?> getLocale()`
  - `Future<void> setLocale(String languageCode)`
  On native this uses a Hive box (reuse the existing auth box or a settings
  box); on web it uses SharedPreferences. Stored as a language code string
  (`"en"` / `"es"`).
- The persisted locale is read at startup so the app opens in the last chosen
  language.

### 3. App wiring

- `lib/app/app.dart` becomes a `ConsumerWidget` that watches `localeProvider`
  and passes to `MaterialApp.router`:
  - `locale: <watched locale>`
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `supportedLocales: AppLocalizations.supportedLocales`
- Switching language updates the provider → `MaterialApp` rebuilds → UI
  re-renders instantly, no restart required. Works with the existing Beamer
  `routerDelegate` / `routeInformationParser` (they are unaffected by locale).

### 4. Settings page

- New page: `lib/presentation/pages/settings/settings_page.dart`.
  - Shows a language selector (Español / English) as a clear choice control
    (segmented control or radio list), reflecting the current `localeProvider`
    value and calling `setLocale` on change.
  - All its own text is localized.
- Registered as a route in `lib/app/router/app_router.dart`.
- Entry point: a settings (gear) icon in the app bar / menu of each role home
  screen — `admin_home_page.dart`, `shop_home_page.dart`,
  `member_home_page.dart` — and accessible from the login/auth area.

### 5. String migration (bulk work)

- Sweep every presentation file (~31 files under `lib/presentation/`,
  ~255 `Text(...)` occurrences plus `title:`, `label:`, `hintText:`,
  `SnackBar`, dialog, button, and tooltip strings) and replace each hardcoded
  UI string with a `context.l10n.<key>` reference, adding the corresponding
  key to both ARB files.
- **Excluded from migration:** product/catalog names (the Spanish item lists
  and Firestore-sourced product data) — left as literal data.
- Dynamic strings use ARB placeholders/plurals rather than string
  concatenation.
- PDF/print output (`lib/data/pdf/`, `lib/presentation/pdf/`): static
  UI-facing labels/headers are localized; catalog/product rows remain data.
  Note: PDF generation has no `BuildContext`, so the required `AppLocalizations`
  instance is passed into the PDF service from the calling widget.

## Component boundaries

- **`localeProvider`** — single source of truth for current locale; owns
  persistence side-effect. Consumers: `app.dart`, settings page.
- **`StorageService.getLocale/setLocale`** — platform-agnostic persistence;
  no knowledge of Riverpod or UI.
- **`AppLocalizations` (generated)** — pure lookup, keyed strings; no app
  logic.
- **Settings page** — pure UI over `localeProvider`.
- Each migrated page/widget depends only on `context.l10n` — no cross-coupling
  introduced.

## Phasing (for reviewability)

1. Setup: dependencies, `l10n.yaml`, `generate: true`, initial ARB files with
   a handful of keys, `context.l10n` extension, verify codegen builds.
2. Locale provider + `StorageService` persistence methods + `app.dart` wiring.
3. Settings page + router route + app-bar entry points on all role homes.
4. String migration, file-group by file-group (auth → shop → admin →
   widgets → pdf), keeping ARB `en`/`es` in parity at each step.
5. Final sweep to confirm no hardcoded UI strings remain (excluding catalog
   data and the brand name).

## Testing / verification

- App builds with l10n codegen (`flutter gen-l10n` / `flutter run`) with no
  errors.
- Toggling language in Settings switches all visible screens live and persists
  after a restart.
- ARB parity check: every key in `app_en.arb` exists in `app_es.arb`.
- Manual walkthrough of each role (admin, shop, member) in both languages to
  confirm no leftover hardcoded text and no missing-key fallbacks.
- Catalog/product names remain unchanged in both languages.

## Out of scope

- Translating product/catalog names.
- Adding languages beyond English and Spanish (structure allows adding more
  later by dropping in another ARB file).
- Right-to-left layout support (not needed for en/es).
