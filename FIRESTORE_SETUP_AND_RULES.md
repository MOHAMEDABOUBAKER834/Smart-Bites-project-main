# Firestore Setup and Security Rules

## 🔧 Step 1: Set Up Firestore Database

To eliminate the Firestore warnings, you need to create a Firestore database:

1. **Go to Firestore Setup:**
   - Visit: https://console.cloud.google.com/datastore/setup?project=smart-bites-2
   - Or go to: https://console.firebase.google.com/project/smart-bites-2/firestore

2. **Create Database:**
   - Click **"Create Database"** button
   - Select **"Start in production mode"** (we'll add rules below)
   - Choose a **location** (e.g., `us-central` or `europe-west`)
   - Click **"Enable"**

3. **Wait for Setup:**
   - Database creation takes 1-2 minutes
   - You'll see "Cloud Firestore" in your Firebase Console

## 🔒 Step 2: Set Up Firestore Security Rules

After creating the database, set up security rules:

1. **Go to Firestore Rules:**
   - In Firebase Console, click **"Firestore Database"** in left sidebar
   - Click the **"Rules"** tab

2. **Copy and Paste These Rules:**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null && request.auth.uid == userId;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Products collection
    match /products/{productId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.sellerId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'seller');
      allow delete: if request.auth != null && 
        (resource.data.sellerId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'seller');
    }
    
    // Orders collection (if you want to use Firestore for orders)
    match /orders/{orderId} {
      allow read: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'seller');
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'seller');
    }
  }
}
```

3. **Click "Publish"**

## ✅ Step 3: Verify

After setup:
- ✅ Firestore warnings will disappear
- ✅ App will work with both Firestore and Realtime Database
- ✅ Products can be stored in Firestore (with Realtime DB fallback)

## 📝 What These Rules Do

- **Users**: Users can only read/write their own data
- **Products**: 
  - Anyone authenticated can read products
  - Anyone can create products
  - Only product owner or sellers can update/delete
- **Orders**: 
  - Users can read their own orders
  - Sellers can read all orders
  - Users can create orders
  - Users and sellers can update orders

## ⚠️ Important Notes

- Setting up Firestore is **optional** - your app works with Realtime Database
- Firestore setup takes about 2 minutes
- Rules take effect immediately after publishing
- You can use both Firestore and Realtime Database together

