# Seller Verification System - Setup Guide

## Overview
This system implements a complete seller verification flow where sellers must upload a restaurant image for admin approval before accessing their dashboard.

## Flow

1. **Sign Up** → User registers as Seller
2. **Email Verification** → User verifies their email
3. **Seller Verification Page** → Seller uploads restaurant image (automatically redirected after email verification)
4. **Verification Pending Screen** → Shows pending status while waiting for admin approval
5. **Admin Approval** → Admin reviews and approves/rejects the seller
6. **Seller Dashboard** → Seller can access dashboard after approval

## Files Created

1. **`lib/seller_verification_page.dart`** - Screen for sellers to upload restaurant image
2. **`lib/verification_pending_screen.dart`** - Screen showing pending verification status
3. **`lib/admin_dashboard.dart`** - Admin dashboard for approving/rejecting sellers

## Files Modified

1. **`lib/auth_screen.dart`** - Modified to redirect sellers to `SellerVerificationPage` after email verification
2. **`lib/user_role_helper.dart`** - Modified to check verification status before navigating sellers to dashboard
3. **`database.rules.json`** - Updated to allow admin access to seller verifications

## Database Structure

### Realtime Database Structure:
```
sellerVerifications/
  {userId}/
    userId: string
    schoolName: string
    email: string
    verificationImage: string (base64 encoded)
    status: "pending" | "approved" | "rejected"
    submittedAt: timestamp

users/
  {userId}/
    ...
    verificationStatus: "pending" | "approved" | "rejected" | null
```

## Setting Up an Admin User

To create an admin user, you need to manually set the role in Firebase Realtime Database:

1. Go to Firebase Console → Realtime Database
2. Navigate to `users/{adminUserId}`
3. Set `role` field to `"Admin"`

**Example:**
```json
{
  "users": {
    "your-admin-user-id": {
      "name": "Admin User",
      "email": "admin@example.com",
      "role": "Admin",
      ...
    }
  }
}
```

## Admin Dashboard Access

- Admin users are automatically redirected to `AdminDashboard` after login
- Admin dashboard shows all pending seller verification requests
- Admin can view restaurant images and approve/reject sellers

## Verification Status Flow

- **null/empty**: Seller needs to upload verification image → Redirects to `SellerVerificationPage`
- **"pending"**: Waiting for admin approval → Shows `VerificationPendingScreen`
- **"approved"**: Seller verified → Redirects to `SellerDashboard`
- **"rejected"**: Verification rejected → Shows rejection message in `VerificationPendingScreen`

## Image Storage

- Images are stored as base64 strings in Realtime Database under `sellerVerifications/{userId}/verificationImage`
- Images are compressed to 85% quality and max dimensions of 1920x1080 before encoding

## Security Rules

The database rules have been updated to:
- Allow sellers to read/write their own verification data
- Allow admins to read/write all verification data
- Allow sellers to read their own verification status
- Allow admins to update any user's verification status

## Testing the Flow

1. **Register as Seller:**
   - Sign up with role "Seller"
   - Verify email
   - Should automatically redirect to `SellerVerificationPage`

2. **Upload Verification Image:**
   - Select image from camera or gallery
   - Upload image
   - Should redirect to `VerificationPendingScreen`

3. **Admin Approval:**
   - Login as admin user
   - Should see `AdminDashboard` with pending verifications
   - View image and approve/reject seller

4. **Seller Access:**
   - After approval, seller should automatically see `SellerDashboard`
   - If rejected, seller sees rejection message

## Notes

- The system uses real-time listeners, so status changes are reflected immediately
- Sellers cannot access their dashboard until approved
- Admin dashboard refreshes automatically when new verification requests are submitted

