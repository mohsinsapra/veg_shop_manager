# Veg Inventory Management App

A Flutter + Firebase mobile application for managing multi-shop vegetable inventory requests.

## 🎯 Overview

This cross-platform mobile app allows multiple vegetable shops to submit daily restocking requests, with admin oversight and consolidated purchase list generation.

## ✨ Features

### For Shop Users
- ✅ Login with email/password authentication
- ✅ Add/edit daily restock requests (until submitted)
- ✅ View current and past requests
- ✅ Real-time request status updates
- ✅ Item management with quantity, unit, and notes

### For Admin Users
- ✅ All shop user capabilities for their own shop
- ✅ View all shop submissions for any day
- ✅ Generate consolidated purchase lists
- ✅ Export purchase lists to PDF/CSV
- ✅ Real-time data synchronization

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter 3.8+
- **Backend**: Firebase (Auth + Firestore)
- **State Management**: Provider
- **Export**: PDF & CSV generation
- **Real-time Updates**: Firestore streams

### Project Structure
```
lib/
├── models/           # Data models
├── services/         # Firebase & business logic
├── providers/        # State management
├── screens/          # UI screens
└── widgets/          # Reusable components
```

## 🔐 Security

- Role-based authentication (admin/shop)
- Firestore security rules prevent data leaks
- Users can only access their own shop data
- Admins have read-only access to all shops

## 🚀 Setup Instructions

### 1. Prerequisites
- Flutter SDK 3.8+
- Firebase CLI
- Node.js (for Firebase CLI)

### 2. Installation
```bash
# Clone and setup
git clone <repository>
cd veg_inventory_app
flutter pub get

# Configure Firebase (follow firebase_setup_instructions.md)
flutterfire configure
```

### 3. Firebase Configuration
See `firebase_setup_instructions.md` for detailed setup steps:
- Create Firebase project
- Enable Authentication
- Set up Firestore
- Deploy security rules
- Add sample data

### 4. Run the App
```bash
flutter run
```

## 📱 Usage

### Initial Setup
1. Create Firebase project and configure
2. Add shop and user data to Firestore
3. Create test user accounts
4. Deploy Firestore security rules

### Daily Workflow
1. **Shop Users**: Login → Add items → Submit request
2. **Admin**: Login → Review all requests → Generate purchase list → Export

### Sample Data
The app includes sample data setup for:
- 2 shops + 1 admin shop
- Test user accounts
- Sample inventory items

## 🔄 Data Flow

```
Shop User → Add Items → Save/Submit Request → Firestore
                                               ↓
Admin User → View All Requests → Generate Consolidated List → Export PDF/CSV
```

## 🔧 Key Components

### Authentication (`auth_provider.dart`)
- Firebase Auth integration
- Role-based routing
- Session management

### Data Management (`firestore_service.dart`)
- CRUD operations
- Real-time streams
- Data validation

### Request Management (`request_provider.dart`)
- Local state management
- Request lifecycle
- Item management

### Export System (`export_service.dart`)
- PDF generation with purchase breakdown
- CSV export for data analysis
- Printing integration

## 🎨 UI Features

- **Material Design**: Clean, intuitive interface
- **Responsive Layout**: Works on phones and tablets
- **Real-time Updates**: Live data synchronization
- **Role-based Navigation**: Different UIs for shop/admin
- **Form Validation**: Robust input validation
- **Export Options**: Multiple output formats

## 📊 Admin Dashboard

- **Summary Cards**: Quick overview of shops, items, quantities
- **Request Management**: View all shop submissions
- **Consolidated View**: Items grouped by type with shop breakdown
- **Export Tools**: PDF and CSV generation
- **Real-time Updates**: Live data from all shops

## 🏪 Shop Interface

- **Request Form**: Add/edit items with quantities and notes
- **Status Tracking**: View submission status
- **History View**: Past requests with details
- **Draft System**: Save work before submitting

## 🔒 Security Rules

Firestore rules ensure:
- Users can only access their own data
- Admins can read all data but respect shop boundaries
- Proper data validation on writes
- Authentication required for all operations

## 🚧 Future Enhancements

- [ ] Push notifications for request deadlines
- [ ] Inventory analytics and trends
- [ ] Master item catalog management
- [ ] Delivery status tracking
- [ ] Multi-language support
- [ ] Offline capability
- [ ] Advanced reporting

## 🐛 Troubleshooting

### Common Issues
1. **Firebase Config**: Ensure `flutterfire configure` completed successfully
2. **Auth Issues**: Check user documents exist in Firestore
3. **Permission Errors**: Verify Firestore rules are deployed
4. **Build Errors**: Run `flutter clean && flutter pub get`

### Dependencies
- All required packages are listed in `pubspec.yaml`
- Compatible with Flutter 3.8+ and Dart 3.0+
- Firebase dependencies are up-to-date

## 📝 License

This project is created for educational and business use.

---

**Built with ❤️ using Flutter + Firebase**