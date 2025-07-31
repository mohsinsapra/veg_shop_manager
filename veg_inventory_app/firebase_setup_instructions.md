# Firebase Setup Instructions

## 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project"
3. Enter project name: `veg-inventory-app`
4. Enable Google Analytics (optional)
5. Click "Create project"

## 2. Enable Authentication

1. In Firebase Console, go to Authentication > Sign-in method
2. Enable "Email/Password" provider
3. Click "Save"

## 3. Create Firestore Database

1. Go to Firestore Database
2. Click "Create database"
3. Choose "Start in test mode" (we'll update rules later)
4. Select a location close to your users
5. Click "Done"

## 4. Set up Flutter Firebase

1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
4. Configure Firebase for Flutter:
   ```bash
   flutterfire configure
   ```
5. Select your Firebase project
6. Select platforms (iOS, Android)

## 5. Add Sample Data

### Create Shops Collection
Add documents to `shops` collection:

```json
// Document ID: shop1
{
  "name": "Downtown Market",
  "location": "123 Main St, Downtown"
}

// Document ID: shop2  
{
  "name": "Westside Grocery",
  "location": "456 West Ave, Westside"
}

// Document ID: admin_shop
{
  "name": "Admin Office Store", 
  "location": "789 Admin Blvd, HQ"
}
```

### Create Users Collection
Add documents to `users` collection:

```json
// Document ID: [user_uid_from_auth]
{
  "email": "shop1@example.com",
  "role": "shop",
  "shopId": "shop1"
}

// Document ID: [admin_user_uid]
{
  "email": "admin@example.com", 
  "role": "admin",
  "shopId": "admin_shop"
}
```

## 6. Create Test Users

1. Go to Authentication > Users
2. Add users manually or use the sign-up functionality
3. Note the UID of each user
4. Add corresponding documents in `users` collection with the UID as document ID

## 7. Deploy Firestore Rules

1. Update `firestore.rules` with the provided rules
2. Deploy rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

## 8. Test the App

1. Run the app: `flutter run`
2. Login with test credentials
3. Test functionality for both shop and admin users

## Sample Test Credentials

You can create these test accounts:

- **Shop User**: shop1@example.com / password123
- **Admin User**: admin@example.com / password123

Make sure to create corresponding user documents in Firestore with the correct roles and shopIds.