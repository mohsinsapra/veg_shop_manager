# GreenChain - Multi-Shop Vegetable Stock Manager

A Flutter application designed for vegetable business owners who operate multiple shops and want a simple system to manage daily inventory needs.

## 🎯 Features

### For Shop Users
- **Daily Inventory Tracking**: Log missing vegetables and quantities for each shop
- **Easy Item Management**: Add, edit, and delete missing items with notes
- **Autocomplete Support**: Quick selection from common vegetables list
- **Shop-Specific Access**: Each shop manages only their own inventory

### For Admin Users
- **Combined Dashboard**: View all missing items from all shops in one place
- **Grouped View**: Items are grouped by name showing total quantities needed
- **Shopping List Generation**: Get a consolidated view of what to buy today
- **Edit Any Entry**: Modify or delete items from any shop as needed

## 🏗️ Architecture

The app follows Clean Architecture principles with:

- **Presentation Layer**: Flutter UI with Riverpod for state management
- **Domain Layer**: Business logic and use cases
- **Data Layer**: Local storage with Hive database
- **Offline-First**: No internet dependency, all data stored locally

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or later)
- Dart SDK
- Android Studio / Xcode for mobile development

### Installation

1. Navigate to the project directory:
```bash
cd veg_shop_manager
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate Hive adapters:
```bash
dart run build_runner build
```

4. Run the app:
```bash
# For mobile (Android/iOS)
flutter run

# For web
flutter run -d chrome
```

## 🔐 Login Credentials

### Shop Login
Select from predefined shops:
- Shop 1 - Downtown
- Shop 2 - Mall  
- Shop 3 - Suburb

### Admin Login
- **Username**: admin
- **Password**: admin123

## 📱 App Structure

```
lib/
├── app/                    # App configuration
│   ├── router/            # Navigation setup
│   └── theme/             # App theming
├── core/                  # Core utilities
│   ├── constants/         # App constants
│   ├── storage/           # Hive box configuration
│   └── utils/             # Utility functions
├── data/                  # Data layer
│   ├── models/            # Hive models
│   ├── datasources/       # Local data sources
│   └── repositories/      # Repository implementations
├── domain/                # Domain layer
│   ├── entities/          # Business entities
│   └── usecases/          # Business logic
└── presentation/          # UI layer
    ├── pages/             # App screens
    ├── widgets/           # Reusable widgets
    └── providers/         # Riverpod providers
```

## 🛠️ Technology Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod 2.x
- **Local Database**: Hive 2.x (Mobile) / SharedPreferences (Web)
- **Navigation**: Beamer 1.x
- **Architecture**: Clean Architecture
- **Design**: Material Design 3
- **Platform Support**: Android, iOS, Web

## 🔮 Future Enhancements

- Firebase integration for cloud sync
- User authentication with Firebase Auth
- PDF export for shopping lists
- Analytics and reporting
- Multi-language support
- Push notifications

## 📝 Development Notes

### Key Design Decisions

1. **Offline-First**: App works without internet connectivity
2. **Cross-Platform Storage**: Hive for mobile (fast NoSQL), SharedPreferences for web compatibility
3. **Clean Architecture**: Separation of concerns for maintainability
4. **Material Design**: Consistent, modern UI following Material Design 3
5. **Web Compatibility**: Automatic storage fallback ensures web platform support

### Testing

Run tests with:
```bash
flutter test
```

### Code Generation

When modifying Hive models, regenerate adapters:
```bash
dart run build_runner build --delete-conflicting-outputs
```

## 🤝 Contributing

1. Follow the established architecture patterns
2. Add tests for new features
3. Update documentation as needed
4. Follow Flutter/Dart best practices
