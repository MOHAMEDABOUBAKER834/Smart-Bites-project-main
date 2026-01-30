# Admin Account Login Guide

## Step 1: Create an Admin Account

### Option A: Create Account in Main App, Then Set as Admin

1. **Open the main Smart Bites app** (`lib/main.dart`)
2. **Register a new account** with email and password
3. **Verify your email** (check your inbox)
4. **Go to Firebase Console**: https://console.firebase.google.com/
5. **Select your project**: smart-bites-2
6. **Click "Realtime Database"** in the left sidebar
7. **Find your user** in the `users` node:
   - Look for your email or UID
   - The UID is shown in Firebase Auth section
8. **Set the role to "Admin"**:
   - Click on your user ID
   - Find or add the `role` field
   - Set value to: `"Admin"` (exactly, case-sensitive)

### Option B: Create Account Directly in Firebase Console

1. **Go to Firebase Console** → Authentication
2. **Click "Add user"**
3. **Enter email and password**
4. **Click "Add user"**
5. **Copy the User UID** (shown after creation)
6. **Go to Realtime Database**
7. **Navigate to** `users/{your-uid}`
8. **Add these fields**:
   ```json
   {
     "name": "Admin User",
     "email": "admin@example.com",
     "role": "Admin",
     "emailVerified": true
   }
   ```

## Step 2: Login to Admin App

### Method 1: Run Admin App

```bash
flutter run -t lib/admin_main.dart
```

### Method 2: Using VS Code/Android Studio

1. **Set entry point** to `lib/admin_main.dart`
2. **Run the app**

### Step 3: Enter Credentials

1. **Open the admin app** (you'll see the Admin Login screen)
2. **Enter your email** (the one you registered with)
3. **Enter your password**
4. **Click "Login"** or press Enter

### Step 4: Verification

- The app will **check if your account has Admin role**
- If verified ✅ → You'll be redirected to **Admin Dashboard**
- If not admin ❌ → You'll see error: "This account is not an admin"

## Quick Setup Script

If you want to quickly create an admin account, you can use this Firebase Console method:

1. **Firebase Console** → Authentication → Add user
   - Email: `admin@smartbites.com`
   - Password: `[your-secure-password]`
   - Copy the UID

2. **Realtime Database** → `users/{UID}` → Add:
   ```json
   {
     "name": "Admin",
     "email": "admin@smartbites.com",
     "role": "Admin",
     "emailVerified": true
   }
   ```

3. **Login** to admin app with:
   - Email: `admin@smartbites.com`
   - Password: `[your-password]`

## Troubleshooting

### "This account is not an admin"
- ✅ Check that `role` field exists in `users/{uid}/role`
- ✅ Check that value is exactly `"Admin"` (capital A, lowercase rest)
- ✅ Make sure you're using the correct user account

### Can't find user in Realtime Database
- Check Firebase Authentication section to get the User UID
- The user might not exist in Realtime Database yet
- Create the user entry manually with the role field

### Login button doesn't work
- Make sure email and password fields are filled
- Check internet connection
- Verify Firebase is properly configured

### App shows "Error checking admin status"
- Check Firebase Realtime Database rules
- Make sure rules allow reading `users/{uid}/role`
- Verify Firebase connection

## Security Notes

⚠️ **Important**: 
- Keep admin credentials secure
- Don't share admin accounts
- Use strong passwords
- Only set trusted users as admins

## Example Admin Account Structure

In Firebase Realtime Database, your admin user should look like:

```
users/
  {admin-user-id}/
    name: "Admin User"
    email: "admin@example.com"
    role: "Admin"          ← This is the key field!
    emailVerified: true
    createdAt: [timestamp]
    ...
```

## Need Help?

If you're still having issues:
1. Check Firebase Console → Realtime Database → users → your user ID
2. Verify the `role` field is set to `"Admin"`
3. Try logging out and logging back in
4. Check the app console for error messages


