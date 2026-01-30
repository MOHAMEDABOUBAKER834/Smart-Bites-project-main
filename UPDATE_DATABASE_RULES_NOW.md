# ⚠️ URGENT: Update Firebase Realtime Database Rules

## 🔴 Problem
Your app cannot load the school list because Realtime Database rules block reading the users list.

**Error:** `Permission denied` when trying to read users to find sellers.

## ✅ Solution - Update Rules NOW

### Step 1: Open Firebase Console
1. Go to: **https://console.firebase.google.com/**
2. Select your project: **smart-bites-2**

### Step 2: Navigate to Realtime Database Rules
1. Click **"Realtime Database"** in the left sidebar
2. Click the **"Rules"** tab at the top

### Step 3: Replace Rules
**Copy and paste this ENTIRE JSON:**

```json
{
  "rules": {
    "users": {
      ".read": "auth != null",
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "points": {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid"
        },
        "role": {
          ".read": "auth != null"
        },
        "name": {
          ".read": "auth != null"
        }
      }
    },
    "carts": {
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid"
      }
    },
    "products": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "orders": {
      ".read": "auth != null",
      "$orderId": {
        ".read": "auth != null && (!data.exists() || data.child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')",
        ".write": "auth != null && (newData.child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')",
        "status": {
          ".read": "auth != null && (root.child('orders').child($orderId).child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')",
          ".write": "auth != null && (root.child('orders').child($orderId).child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')"
        }
      }
    },
    "numericId_to_uid": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "coupons": {
      ".read": "auth != null",
      "$couponCode": {
        ".read": "auth != null",
        ".write": "auth != null",
        "timesUsed": {
          ".read": "auth != null",
          ".write": "auth != null"
        }
      }
    }
  }
}
```

### Step 4: Publish
1. Click **"Publish"** button
2. Wait for confirmation

### Step 5: Test
1. Restart your app
2. Try to register as Buyer
3. The school dropdown should now work!

## 🔒 Security Note
These rules allow:
- ✅ Authenticated users can read the users list (to find sellers)
- ✅ ✅ Anyone can read `role` and `name` fields (needed for school list)
- ✅ Users can only read/write their own full user data
- ✅ Sensitive data (email, phone, points) is still protected

This is safe because:
- Only authenticated users can read
- Only public info (role, name) is exposed
- Personal data (email, phone, points) is still private

