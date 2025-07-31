🧾 Project Idea: Multi-Shop Vegetable Stock Manager App
💡 Overview
This application is designed for a vegetable business owner who operates multiple shops and wants a simple system to manage daily inventory needs. Each shop logs in daily and submits a list of vegetables or items that are missing or low in stock. The admin (business owner or manager) logs in separately to see a combined summary of all missing items across shops and can update or edit any of the entries if needed. This allows the owner to quickly generate a daily shopping list and ensure that each shop is well-stocked.

Name: GreenChain


🧭 Goals
Simplify daily inventory reporting across multiple shops.

Provide each shop a login to submit their own list of missing items.

Allow the admin to access a combined view of all shop needs.

Make the app usable offline first (no internet dependency initially).

Design the architecture to support Firebase integration later (for real-time cloud sync and authentication).

👥 User Roles
Shop User

Logs in with shop credentials.

Adds missing vegetables/items with quantity and notes.

Can view or update their own entries for the day.

Admin

Logs in with separate credentials.

Views a combined list of all missing items from every shop.

Can edit or add missing items manually for any shop.

Can generate or print a final list of what to buy today.

🔒 Initial Design Constraints
No Firebase initially — local-only using Hive database.

Simple login flow using predefined credentials stored locally.

Offline-first architecture with data stored and retrieved from device storage.

Focus on clean, modern UI and separation of logic using clean architecture.

🔮 Future Scope
Firebase Auth for secure login per shop

Firestore for real-time cloud sync of missing items

Print/PDF export of the admin shopping list

Analytics and item tracking (which items are often needed?)




🧩 Dependencies & Why
yaml
Copy
Edit
environment:
  sdk: ^3.8.1

dependencies:
  flutter:
    sdk: flutter

  # 🌐 Routing
  beamer: ^1.7.0                     # Declarative routing with nested support

  # 📦 State Management
  flutter_riverpod: ^2.6.1           # Scalable state and DI system

  # 🗃 Local Storage
  hive: ^2.2.3                       # Lightweight NoSQL for offline-first apps
  hive_flutter: ^1.1.0               # Flutter bindings for Hive
  uuid: ^4.5.1                       # Unique IDs for entries

  # 📱 UI & Utilities
  cupertino_icons: ^1.0.8
  flutter_svg: ^2.2.0                # SVG support for icons
  intl: ^0.19.0                      # For date formatting
  url_launcher: ^6.3.1               # For launching print preview or sharing PDF later

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.5.4
  hive_generator: ^2.0.1             # For Hive model adapters
  flutter_lints: ^3.0.0
📁 Folder Structure
bash
Copy
Edit
lib/
├── app/
│   ├── app.dart                    # Root widget
│   ├── router/app_router.dart      # Beamer routing logic
│   └── theme/app_theme.dart        # Light/Dark Theme
├── core/
│   ├── constants/app_constants.dart
│   ├── storage/hive_boxes.dart     # Hive box definitions
│   └── utils/date_utils.dart
├── data/
│   ├── models/
│   │   ├── missing_item.dart       # Hive model
│   │   └── user_role.dart
│   ├── datasources/local/
│   │   └── missing_item_local_ds.dart
│   └── repositories/
│       └── missing_item_repo.dart
├── domain/
│   ├── entities/missing_item_entity.dart
│   └── usecases/
│       └── submit_missing_item.dart
├── presentation/
│   ├── pages/
│   │   ├── login/
│   │   │   └── login_page.dart
│   │   ├── shop/
│   │   │   ├── shop_home_page.dart
│   │   │   └── add_item_page.dart
│   │   └── admin/
│   │       └── admin_page.dart
│   ├── widgets/
│   │   └── item_card.dart
│   └── providers/
│       ├── auth_provider.dart
│       └── missing_item_provider.dart
└── main.dart
🔌 Wiring the Project
1. main.dart
dart
Copy
Edit
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(MissingItemAdapter());
  Hive.registerAdapter(UserRoleAdapter());

  await Hive.openBox<MissingItem>('missing_items');
  await Hive.openBox<String>('auth');

  runApp(const ProviderScope(child: VegShopApp()));
}
2. Login System
Use local Hive box auth with a predefined list of shop usernames and one admin.

Shop login stores shopId in memory for filtering.

Admin login shows aggregated view.

3. Routing Setup (Beamer)
dart
Copy
Edit
final routerDelegate = BeamerDelegate(
  initialPath: '/',
  locationBuilder: RoutesLocationBuilder(
    routes: {
      '/': (context, state, data) => const BeamPage(child: LoginPage()),
      '/shop': (context, state, data) => const BeamPage(child: ShopHomePage()),
      '/admin': (context, state, data) => const BeamPage(child: AdminPage()),
    },
  ),
);
4. MissingItem Model (Hive)
dart
Copy
Edit
@HiveType(typeId: 0)
class MissingItem extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String itemName;
  @HiveField(2) final int quantity;
  @HiveField(3) final String shopId;
  @HiveField(4) final DateTime date;

  MissingItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.shopId,
    required this.date,
  });
}
5. Providers (Riverpod)
authProvider – manages current logged-in user/shop.

missingItemProvider – add/edit/delete items.

combinedItemProvider – aggregates items for admin.

6. Shop Features
After login, shop sees list of items added today.

Can add/edit today’s missing items.

Saved using Hive.box<MissingItem>('missing_items').

7. Admin Features
See list of all missing items from all shops (filtered by today’s date).

Grouped by item (e.g., 10 tomatoes from 3 shops).

Can edit any item.

(Later: option to export/print list)

8. Future Firebase Integration Plan
Replace the following:

Hive → Cloud Firestore

Local auth → Firebase Auth (Shop users and Admin via roles)

Sync MissingItem with Firestore

Use Firebase Functions for aggregation, if needed

✅ Setup Checklist
flutter create veg_shop_manager

Add dependencies in pubspec.yaml

Setup folders as per structure

Create Hive models and register adapters

Setup Beamer router

Build login page with dropdown or ID+PIN login

Build shop item input page (with DateTime.now() tag)

Build admin view with combined list