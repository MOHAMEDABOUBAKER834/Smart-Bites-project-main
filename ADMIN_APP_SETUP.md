# Admin App - Separate Application Setup

## Overview
The admin dashboard is now a completely separate application that can be run independently from the main Smart Bites app.

## Files Created

1. **`lib/admin_main.dart`** - Main entry point for the admin app
2. **`lib/admin_login_screen.dart`** - Login screen specifically for admin users
3. **`lib/admin_dashboard.dart`** - Admin dashboard (already existed, updated for separate app)

## Running the Admin App

### Option 1: Using Flutter Run with Target File

```bash
flutter run -t lib/admin_main.dart
```

### Option 2: Create a Separate Launch Configuration

#### VS Code (.vscode/launch.json)
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Smart Bites Admin",
      "request": "launch",
      "type": "dart",
      "program": "lib/admin_main.dart"
    },
    {
      "name": "Smart Bites Main",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart"
    }
  ]
}
```

#### Android Studio
1. Go to Run → Edit Configurations
2. Click "+" → Flutter
3. Name: "Smart Bites Admin"
4. Dart entrypoint: `lib/admin_main.dart`
5. Click OK

### Option 3: Create Separate Build Variants (Advanced)

You can create separate Android build variants or iOS schemes for the admin app.

## Admin Login

1. **Start the admin app** using one of the methods above
2. **Login** with an admin account email and password
3. The app will **verify** that the account has `role: "Admin"` in Firebase
4. If verified, you'll be redirected to the **Admin Dashboard**
5. If not an admin, you'll see an error and be logged out

## Setting Up Admin Users

To create an admin user:

1. **Create a regular user account** in the main Smart Bites app (or Firebase Console)
2. **Go to Firebase Console** → Realtime Database
3. **Navigate to** `users/{userId}`
4. **Set the `role` field** to `"Admin"`

Example:
```json
{
  "users": {
    "admin-user-id-here": {
      "name": "Admin User",
      "email": "admin@example.com",
      "role": "Admin",
      "emailVerified": true,
      ...
    }
  }
}
```

## Features

### Admin Login Screen
- Email/password authentication
- Automatic admin role verification
- Error handling for non-admin accounts
- Bilingual support (Arabic/English)

### Admin Dashboard
- View all pending seller verification requests
- View restaurant images uploaded by sellers
- Approve or reject seller verifications
- Real-time updates when new requests come in
- Pull-to-refresh functionality
- Logout functionality

## Security

- Only users with `role: "Admin"` can access the admin dashboard
- Non-admin users are automatically logged out if they try to access
- All admin operations require Firebase authentication
- Database rules enforce admin-only access to verification data

## Differences from Main App

1. **Separate entry point** (`admin_main.dart` vs `main.dart`)
2. **Admin-only login** (checks for Admin role)
3. **No buyer/seller features** - only admin verification management
4. **Simplified navigation** - goes directly to admin dashboard after login

## Troubleshooting

### "This account is not an admin"
- Make sure the user's `role` field is set to `"Admin"` (case-sensitive) in Firebase Realtime Database
- Check that you're logged in with the correct account

### Can't run admin app
- Make sure you're using `flutter run -t lib/admin_main.dart`
- Or configure your IDE to use `lib/admin_main.dart` as the entry point

### Admin dashboard shows no pending verifications
- Check that sellers have uploaded verification images
- Verify that `sellerVerifications` exists in Firebase Realtime Database
- Check database rules allow admin read access

## Notes

- The admin app uses the same Firebase project as the main app
- Both apps can run simultaneously on different devices/emulators
- Admin users can still use the main app with their admin account (they'll be redirected to admin dashboard if role is Admin)

