# Seller Verification Flow Fix

## Problem
After email verification, sellers were going directly to `VerificationPendingScreen` instead of `SellerVerificationPage` to upload their restaurant image first. This meant no verification requests appeared in the admin dashboard because no image was uploaded.

## Root Cause
In `auth_screen.dart`, when a seller registered, `verificationStatus` was being set to `'pending'` immediately during registration, before the seller had uploaded their verification image. This caused the navigation logic to skip the image upload step.

## Solution

### 1. Fixed Registration Flow (`lib/auth_screen.dart`)
- **Removed** the automatic setting of `verificationStatus: 'pending'` during registration
- Now `verificationStatus` is `null` when a seller first registers
- This ensures sellers must upload their image before the status becomes 'pending'

### 2. Enhanced Navigation Logic (`lib/user_role_helper.dart`)
- Added a **safety check** in `_getVerificationStatus()`:
  - If status is `'pending'` but no verification image exists in `sellerVerifications/{userId}`, it returns `null`
  - This forces a redirect to `SellerVerificationPage` to upload the image
- Navigation flow:
  - `verificationStatus == null` → `SellerVerificationPage` (upload image)
  - `verificationStatus == 'pending'` → `VerificationPendingScreen` (waiting for admin)
  - `verificationStatus == 'approved'` → `SellerDashboard` (verified)

## Correct Flow Now

1. **Seller Registers**
   - Email, password, role = 'Seller'
   - `verificationStatus` = `null` (NOT set to 'pending')

2. **Email Verification**
   - Seller verifies email
   - `UserRoleHelper.navigateBasedOnRole()` checks status
   - Status is `null` → Redirects to `SellerVerificationPage`

3. **Image Upload** (`SellerVerificationPage`)
   - Seller uploads restaurant image
   - Image saved to `sellerVerifications/{userId}` with:
     - `verificationImage`: base64 encoded image
     - `status`: 'pending'
     - `schoolName`, `email`, `submittedAt`
   - `users/{userId}/verificationStatus` set to 'pending'
   - Redirects to `VerificationPendingScreen`

4. **Admin Review** (`AdminDashboard`)
   - Admin sees pending verification requests
   - Admin can view image and approve/reject
   - When approved:
     - `sellerVerifications/{userId}/status` → 'approved'
     - `users/{userId}/verificationStatus` → 'approved'

5. **Seller Dashboard Access**
   - `VerificationPendingScreen` listens to status changes
   - When status becomes 'approved', redirects to `SellerDashboard`

## Testing Checklist

- [ ] Seller registers with role 'Seller'
- [ ] After email verification, goes to `SellerVerificationPage`
- [ ] Can upload restaurant image
- [ ] After upload, goes to `VerificationPendingScreen`
- [ ] Admin sees verification request in dashboard
- [ ] Admin can view image
- [ ] Admin can approve/reject
- [ ] Seller is redirected to dashboard when approved

## Files Modified

1. `lib/auth_screen.dart` - Removed premature `verificationStatus: 'pending'` setting
2. `lib/user_role_helper.dart` - Added safety check for verification image existence

