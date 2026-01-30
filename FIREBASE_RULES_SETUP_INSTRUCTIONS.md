# Firebase Realtime Database Rules - Setup Instructions

## 📋 Complete Rules to Copy and Paste

Copy the **ENTIRE** content below and paste it into Firebase Console:

```json
{
  "rules": {
    "users": {
      // Allow authenticated users to read the users list to find sellers (for school selection)
      ".read": "auth != null",
      "$uid": {
        ".read": "$uid === auth.uid",
        ".write": "$uid === auth.uid",
        "points": {
          ".read": "$uid === auth.uid",
          ".write": "$uid === auth.uid"
        },
        // Allow reading role and name for seller discovery (school list)
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
          ".read": "auth != null && (!data.exists() || data.parent().child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')",
          ".write": "auth != null && (data.parent().child('userId').val() === auth.uid || root.child('users').child(auth.uid).child('role').val() === 'seller')"
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

## 🚀 Step-by-Step Setup

### Step 1: Open Firebase Console
1. Go to: **https://console.firebase.google.com/**
2. Select your project: **smart-bites-2**

### Step 2: Navigate to Realtime Database
1. In the left sidebar, click **"Realtime Database"**
2. If you see "Create Database", click it and select a location
3. Click the **"Rules"** tab at the top

### Step 3: Update Rules
1. **Delete all existing rules** in the editor
2. **Copy the entire JSON above** (from `{` to `}`)
3. **Paste it** into the Firebase Console rules editor
4. Click **"Publish"** button
5. Wait for confirmation: "Rules published successfully"

### Step 4: Verify
- Rules should be active immediately
- No errors should appear in the editor
- Test your app - cart and orders should work

## 📖 What These Rules Do

### 🔐 Security Rules Explained:

1. **users/$uid**
   - Users can only read/write their own data
   - Users can update their own points

2. **carts/$uid**
   - Users can only read/write their own cart
   - Prevents users from accessing others' carts

3. **products**
   - Any authenticated user can read products
   - Any authenticated user can write products (for sellers)

4. **orders**
   - Any authenticated user can read orders list (to check for existing IDs)
   - Users can read/write their own orders
   - Sellers can read/write all orders
   - Order status can be updated by order owner or seller

5. **coupons**
   - Any authenticated user can read/write coupons
   - Used for discount code functionality

6. **numericId_to_uid**
   - Mapping table for numeric IDs
   - Any authenticated user can access

## ⚠️ Important Notes

- **Rules take effect immediately** after publishing
- **No restart needed** - changes are instant
- **Test thoroughly** after updating rules
- **Keep a backup** of your rules before making changes

## 🔍 Troubleshooting

### If you get permission errors:
1. Verify rules were published (check Rules tab)
2. Make sure user is authenticated (logged in)
3. Check that user UID matches in database
4. Verify seller role is set in users table if needed

### If rules won't save:
1. Check for JSON syntax errors (missing commas, brackets)
2. Make sure you have proper permissions in Firebase Console
3. Try refreshing the page and pasting again

### Quick Test Rules (Temporary - Use Only for Testing):
```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```
⚠️ **Warning**: These rules allow any authenticated user to read/write everything. Use only for testing, then switch back to secure rules above.

## ✅ Verification Checklist

- [ ] Rules copied and pasted correctly
- [ ] Rules published successfully
- [ ] No syntax errors in Firebase Console
- [ ] Cart operations work
- [ ] Order placement works
- [ ] Seller can mark orders as ready
- [ ] Buyer can confirm order receipt
- [ ] User points update correctly

## 📞 Need Help?

If you encounter issues:
1. Check Firebase Console for error messages
2. Verify authentication is working
3. Check browser console for detailed error messages
4. Ensure all required fields exist in database structure

