# Quick Admin Login Guide 🚀

## 📋 Simple Steps

### 1️⃣ Create Admin Account

**Option 1: Via Firebase Console (Fastest)**
```
1. Go to: https://console.firebase.google.com/
2. Select project: smart-bites-2
3. Click "Authentication" → "Add user"
4. Enter email & password → Click "Add user"
5. Copy the User UID (shown after creation)
6. Click "Realtime Database"
7. Go to: users/{paste-uid-here}
8. Click "Add field" → Name: "role" → Value: "Admin"
9. Click "Add field" → Name: "email" → Value: [your-email]
10. Click "Add field" → Name: "name" → Value: "Admin"
```

**Option 2: Via Main App**
```
1. Run main app: flutter run -t lib/main.dart
2. Register new account
3. Verify email
4. Go to Firebase Console → Realtime Database
5. Find your user → Set role = "Admin"
```

### 2️⃣ Run Admin App

```bash
flutter run -t lib/admin_main.dart
```

### 3️⃣ Login

```
Email: [your-admin-email]
Password: [your-password]
Click: "Login"
```

### 4️⃣ Access Dashboard

✅ If admin → You'll see the Admin Dashboard
❌ If not admin → Error: "This account is not an admin"

---

## 🔍 Verify Admin Status

**Check in Firebase Console:**
```
Realtime Database → users → {your-uid} → role
Should show: "Admin"
```

**If missing:**
- Click on your user ID
- Click "Add field"
- Field name: `role`
- Field value: `Admin` (exact, case-sensitive)

---

## ⚠️ Common Issues

| Problem | Solution |
|---------|----------|
| "Not an admin" error | Set `role: "Admin"` in Firebase |
| Can't find user | Check Authentication → Copy UID |
| Login doesn't work | Check email/password are correct |
| App won't run | Use: `flutter run -t lib/admin_main.dart` |

---

## 📱 Example

**Firebase Realtime Database Structure:**
```
users/
  └── abc123xyz789/          ← Your User UID
      ├── email: "admin@example.com"
      ├── name: "Admin User"
      └── role: "Admin"       ← MUST BE EXACTLY "Admin"
```

---

## 🎯 Quick Test

1. ✅ Create account in Firebase Console
2. ✅ Set role = "Admin" in Realtime Database
3. ✅ Run: `flutter run -t lib/admin_main.dart`
4. ✅ Login with email/password
5. ✅ Should see Admin Dashboard!

---

**Need more help?** See `ADMIN_LOGIN_GUIDE.md` for detailed instructions.


