# DanceRang Firestore Security Rules

This document explains the Firestore security rules implementation for the DanceRang app and how to deploy them.

## 📋 Overview

The security rules implement role-based access control with the following key principles:

- **Users** can manage their own profiles and registrations
- **Admins** have full access to all collections
- **Public content** is readable by everyone, writable only by admins
- **Role escalation** is prevented (only admins can change user roles)
- **Timestamps** are automatically managed by the server

## 🏗️ Collection Structure

### User Management
- `users/{userId}` - User profiles with role-based access

### Public Content (Read-only for users, Admin-write)
- `banners/{bannerId}` - App banners
- `updates/{updateId}` - App updates/announcements
- `classes/{classId}` - Dance classes
- `workshops/{workshopId}` - Dance workshops
- `onlineVideos/{videoId}` - Online video content

### App Configuration
- `appSettings/{settingId}` - App configuration (read-only for users, Admin-write)

### User Data
- `classRegistrations/{registrationId}` - Class registrations
- `workshopRegistrations/{registrationId}` - Workshop registrations
- `eventChoreoBookings/{bookingId}` - Event and choreography bookings
- `bookings/{bookingId}` - General bookings
- `notifications/{notificationId}` - User notifications

### Admin Only
- `analytics/{logId}` - Analytics data
- `systemLogs/{logId}` - System logs

## 🔐 Security Rules

### Helper Functions

```javascript
function isSignedIn() {
  return request.auth != null;
}

function isAdmin() {
  return isSignedIn() && (
    request.auth.token.admin == true ||
    request.auth.uid in ['admin_uid_1', 'admin_uid_2'] // Fallback UIDs
  );
}

function isOwner(uid) {
  return isSignedIn() && request.auth.uid == uid;
}
```

### Access Patterns

1. **Users Collection**
   - Read: Own profile OR admin
   - Create: Own profile with valid data
   - Update: Own profile (no role escalation) OR admin
   - Delete: Admin only

2. **Public Content**
   - Read: Everyone
   - Write: Admin only

3. **Registrations/Bookings**
   - Read: Own records OR admin
   - Create: Own records only
   - Update: Own records OR admin
   - Delete: Own records OR admin

4. **App Settings**
   - Read: Everyone
   - Write: Admin only

## 🚀 Deployment

### Prerequisites

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize Firebase in your project:
   ```bash
   firebase init firestore
   ```

### Deploy Rules and Indexes

```bash
# Deploy only Firestore rules and indexes
firebase deploy --only firestore:rules,firestore:indexes

# Or deploy everything
firebase deploy
```

### Verify Deployment

```bash
# Check deployment status
firebase projects:list

# View rules in Firebase Console
firebase open firestore:rules
```

## 👑 Admin Management

### Setting Admin Claims

1. **Using the provided script:**
   ```bash
   # Set admin claim for a user
   node scripts/setAdminClaim.js set <user_uid>
   
   # Remove admin claim
   node scripts/setAdminClaim.js remove <user_uid>
   
   # List all admin users
   node scripts/setAdminClaim.js list
   ```

2. **Using Firebase Admin SDK directly:**
   ```javascript
   const admin = require('firebase-admin');
   
   // Set admin claim
   await admin.auth().setCustomUserClaims(uid, { admin: true });
   
   // Remove admin claim
   await admin.auth().setCustomUserClaims(uid, { admin: false });
   ```

3. **Using Firebase Console:**
   - Go to Authentication > Users
   - Select user > Custom Claims
   - Add `{"admin": true}`

### Fallback Admin UIDs

Update the `isAdmin()` function in `firestore.rules` to include fallback admin UIDs:

```javascript
function isAdmin() {
  return isSignedIn() && (
    request.auth.token.admin == true ||
    request.auth.uid in ['your_admin_uid_1', 'your_admin_uid_2']
  );
}
```

## 🧪 Testing

### Run Security Rules Tests

```bash
# Install test dependencies
npm install --save-dev @firebase/rules-unit-testing

# Run tests
node scripts/test-firestore-rules.js
```

### Test Scenarios Covered

- ✅ Users can read/write their own profiles
- ✅ Users cannot read other users' profiles
- ✅ Users cannot escalate their own roles
- ✅ Admins can read/write any user profile
- ✅ Everyone can read public content
- ✅ Only admins can write public content
- ✅ Users can create/read their own registrations
- ✅ Users cannot create registrations for others
- ✅ Unauthenticated users are denied access to user data

## 📊 Indexes

The `firestore.indexes.json` file includes compound indexes for:

- User registrations (by userId + createdAt)
- Bookings (by userId + status + createdAt)
- Classes/Workshops (by isActive + date)
- Notifications (by userId + isRead + createdAt)

## 🔧 Configuration

### Environment Variables

Set these environment variables for admin scripts:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="path/to/service-account-key.json"
export FIREBASE_PROJECT_ID="dancerang-733ea"
```

### Service Account Setup

1. Go to Firebase Console > Project Settings > Service Accounts
2. Generate new private key
3. Save as `service-account-key.json`
4. Update path in `scripts/setAdminClaim.js`

## 🚨 Important Notes

1. **Role Escalation Prevention**: Users cannot change their own role to Admin
2. **Timestamp Management**: Server timestamps are enforced for `createdAt` and `updatedAt`
3. **Data Validation**: User data must include required fields and valid role values
4. **Admin Fallback**: Hardcoded admin UIDs provide fallback if custom claims fail
5. **Public Content**: All public collections follow the same read-everyone, write-admin pattern

## 🔍 Monitoring

Monitor rule usage in Firebase Console:
- Go to Firestore > Usage
- Check "Rules evaluations" for performance
- Monitor "Denied requests" for security issues

## 📞 Support

For issues with security rules:
1. Check Firebase Console for rule evaluation errors
2. Run the test suite to verify rule behavior
3. Check admin claim configuration
4. Verify user authentication status

## 🔄 Updates

When updating rules:
1. Test changes locally first
2. Deploy to staging environment
3. Run full test suite
4. Deploy to production
5. Monitor for any issues

---

**Last Updated**: $(date)
**Version**: 1.0.0
**Firebase Project**: dancerang-733ea
