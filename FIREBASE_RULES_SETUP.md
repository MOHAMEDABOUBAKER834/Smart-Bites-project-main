# Firebase Realtime Database Rules Setup Guide

## ⚠️ IMPORTANT: You MUST update Firebase Console rules for the cart to work!

The permission denied error occurs because Firebase security rules haven't been configured yet.

## Step-by-Step Instructions:

### 1. Open Firebase Console
- Go to: https://console.firebase.google.com/
- Select your project: **smart-bites-2**

### 2. Navigate to Realtime Database
- Click **"Realtime Database"** in the left sidebar
- Click the **"Rules"** tab at the top

### 3. Copy and Paste These Rules

**Copy the ENTIRE content from `database.rules.json` file and paste it into Firebase Console:**

**Copy the ENTIRE content from `database.rules.json` file and paste it into Firebase Console.**

The rules file contains all the necessary permissions for:
- Cart operations (add, read, delete)
- Order placement (create orders, read orders)
- User points updates
- Coupon usage tracking

### 4. Publish the Rules
- Click the **"Publish"** button
- Wait for confirmation that rules are published

### 5. Test Your App
- Restart your Flutter app
- Try adding an item to cart
- It should work now!

## Quick Test (Temporary - Use Only for Testing)

If you want to quickly test, you can temporarily use these open rules (⚠️ NOT SECURE):

```json
{
  "rules": {
    ".read": "auth != null",
    ".write": "auth != null"
  }
}
```

**⚠️ WARNING:** The test rules above allow any authenticated user to read/write everything. Only use for testing, then switch to the secure rules above.

## What These Rules Do:

- **carts**: Users can only read/write their own cart (based on their user ID)
- **products**: Any authenticated user can read/write products
- **orders**: Users can read/write their own orders; sellers can read/write all orders
- **users**: Users can only read/write their own user data

## Troubleshooting:

1. **Still getting permission denied?**
   - Make sure you clicked "Publish" after pasting the rules
   - Wait a few seconds for rules to propagate
   - Restart your app completely
   - Check that you're logged in (auth.uid should not be null)

2. **Rules not saving?**
   - Make sure you have proper permissions in Firebase Console
   - Try refreshing the page and pasting again

3. **Need help?**
   - Check Firebase Console for any error messages
   - Verify your user is authenticated (check logs for user UID)

