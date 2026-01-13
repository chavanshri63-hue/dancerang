#!/bin/bash

# Dancerang Project Backup Script for Google Drive
# This script creates a clean backup of the project for Google Drive

echo "🚀 Starting Dancerang Project Backup..."

# Get current date for backup naming
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="DancerangProject_${BACKUP_DATE}"

# Create backup directory
BACKUP_DIR="/Users/shreechavan/Google Drive/DancerangBackup/${BACKUP_NAME}"
mkdir -p "$BACKUP_DIR"

echo "📁 Creating backup in: $BACKUP_DIR"

# Copy project files (excluding build files)
echo "📋 Copying project files..."
rsync -av --exclude-from='.gitignore' \
  --exclude='build/' \
  --exclude='ios/Pods/' \
  --exclude='node_modules/' \
  --exclude='.DS_Store' \
  /Users/shreechavan/dancerang/ "$BACKUP_DIR/"

# Create setup instructions
echo "📝 Creating setup instructions..."
cat > "$BACKUP_DIR/SETUP_INSTRUCTIONS.md" << 'EOF'
# Dancerang Project Setup Instructions

## Prerequisites
1. Install Flutter SDK
2. Install Xcode (for iOS development)
3. Install Android Studio (for Android development)
4. Install CocoaPods: `sudo gem install cocoapods`

## Setup Steps

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. iOS Setup
```bash
cd ios
pod install
cd ..
```

### 3. Run Project
```bash
flutter run --debug
```

## Important Files
- `android/app/google-services.json` - Firebase Android config
- `ios/Runner/GoogleService-Info.plist` - Firebase iOS config
- `firebase.json` - Firebase project config
- `firestore.rules` - Firestore security rules

## Firebase Setup
1. Create new Firebase project
2. Add Android app with package name: `com.dancerang.dancerang`
3. Add iOS app with bundle ID: `com.dancerang.dancerang`
4. Download and replace config files
5. Enable Authentication, Firestore, Storage, Functions

## Razorpay Setup
1. Get Razorpay API keys
2. Update in `lib/services/payment_service.dart`
3. Update in `functions/src/razorpay.ts`

## Admin Setup
1. Create admin user in Firebase Auth
2. Set custom claim: `{role: 'admin'}`
3. Use admin email for testing

## Features Included
- ✅ User Authentication (OTP)
- ✅ Role-based Access Control
- ✅ Class Management
- ✅ Payment Integration (Razorpay)
- ✅ Real-time Notifications
- ✅ Admin Dashboard
- ✅ Student Management
- ✅ Faculty Management
- ✅ Attendance Tracking
- ✅ Gallery Management
- ✅ Event Management

## Contact
For any issues, contact the development team.
EOF

# Create Firebase config backup
echo "🔥 Backing up Firebase configurations..."
mkdir -p "$BACKUP_DIR/firebase_configs"
cp android/app/google-services.json "$BACKUP_DIR/firebase_configs/" 2>/dev/null || echo "Android config not found"
cp ios/Runner/GoogleService-Info.plist "$BACKUP_DIR/firebase_configs/" 2>/dev/null || echo "iOS config not found"
cp firebase.json "$BACKUP_DIR/firebase_configs/" 2>/dev/null || echo "Firebase config not found"
cp firestore.rules "$BACKUP_DIR/firebase_configs/" 2>/dev/null || echo "Firestore rules not found"
cp storage.rules "$BACKUP_DIR/firebase_configs/" 2>/dev/null || echo "Storage rules not found"

# Create project info
echo "📊 Creating project information..."
cat > "$BACKUP_DIR/PROJECT_INFO.txt" << EOF
Dancerang Project Backup
Created: $(date)
Flutter Version: $(flutter --version | head -1)
Project Size: $(du -sh /Users/shreechavan/dancerang | cut -f1)
Backup Size: $(du -sh "$BACKUP_DIR" | cut -f1)

Features:
- Complete Flutter app with Firebase integration
- Role-based authentication (Admin, Faculty, Student, Guest)
- Payment processing with Razorpay
- Real-time notifications
- Class management system
- Student and faculty management
- Attendance tracking
- Gallery and event management

Backup includes:
- All source code
- Firebase configurations
- Setup instructions
- Project documentation
EOF

echo "✅ Backup completed successfully!"
echo "📁 Backup location: $BACKUP_DIR"
echo "📊 Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)"
echo ""
echo "🔄 Next steps:"
echo "1. Check Google Drive sync status"
echo "2. Verify all files are uploaded"
echo "3. Test backup by downloading and setting up on another machine"
echo ""
echo "🎉 Your Dancerang project is now safely backed up to Google Drive!"
