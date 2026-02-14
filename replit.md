# DanceRang - Dance Studio Management App

## Overview
DanceRang is a comprehensive dance studio management Flutter application built for students, faculty, and administrators. It uses Firebase for backend services including authentication, Firestore database, Cloud Functions, Storage, and Analytics.

## Project Architecture
- **Framework**: Flutter (Dart) with web support
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Storage, Analytics, Messaging)
- **State Management**: Provider (AppAuthProvider for auth state, role, role keys)
- **Payment**: Razorpay integration (mobile-only)
- **Build**: Flutter web build served via Python HTTP server

## Project Structure
- `lib/` - Main Dart source code
  - `main.dart` - App entry point with Firebase initialization and MultiProvider
  - `providers/` - State management providers
    - `auth_provider.dart` - AppAuthProvider (user state, role, role keys)
  - `screens/` - UI screens (login, home, admin dashboards, etc.)
    - `home_screen.dart` - Main home shell with bottom navigation (uses part files)
    - `tabs/` - Home screen tab files (part of home_screen.dart)
      - `home_tab.dart` - Home feed, banners, features grid
      - `classes_tab.dart` - Class listings, details, packages
      - `studio_tab.dart` - Studio booking, availability
      - `online_tab.dart` - Online videos, style cards
      - `profile_tab.dart` - Profile, enrollment, payments, admin stats
  - `services/` - Business logic services (payment, attendance, notifications, etc.)
  - `models/` - Data models
  - `widgets/` - Reusable UI components
  - `config/` - App configuration (no hardcoded secrets)
  - `utils/` - Utility files including web stubs
- `web/` - Web-specific files (index.html, manifest.json)
- `android/` - Android platform files
- `functions/` - Firebase Cloud Functions (Node.js/TypeScript)
- `assets/` - App assets (icons, images)
- `serve.py` - Python HTTP server for serving Flutter web build on port 5000

## Running the App
The workflow builds Flutter for web and serves the output on port 5000:
```
flutter build web --release --base-href "/" && python3 serve.py
```

## Security Notes
- Admin/Faculty role keys loaded from Firestore (`appSettings/roleKeys`) as primary source
- Build-time secrets via `--dart-define` (ADMIN_KEY, FACULTY_KEY) as fallback
- No hardcoded credentials in source code
- Clear error messages when keys are not configured

## Web Compatibility Notes
- `qr_code_scanner` replaced with local stub (`lib/utils/qr_stub.dart`) - QR scanning is mobile-only
- `razorpay_flutter` guarded with `kIsWeb` check - payments are mobile-only
- Firebase Messaging (FCM) guarded with `kIsWeb` - push notifications not supported on web in this environment
- `in_app_purchase` lazy-loaded to avoid web initialization errors
- SDK constraint set to `^3.8.0` for compatibility with available Flutter SDK

## Recent Changes
- 2026-02-14: Notification audit & fixes (mobile-focused, no UI/behavior changes)
  - Added "2 classes remaining" warning: writes to student's Firestore notification subcollection when attendance marking reduces remainingSessions to 2
  - Created Cloud Function `onApprovalCreated` (Firestore trigger on `approvals/{id}`) to notify all admin/faculty of new cash payment and join requests via FCM + in-app
  - Created Cloud Function `onStudioBookingCreated` (Firestore trigger on `studioBookings/{id}`) to notify all admin/faculty of new studio bookings via FCM + in-app
  - Fixed new class notifications: replaced local per-student loop with single `notifications` collection write, triggering existing `sendAdminNotification` Cloud Function for FCM broadcast
  - Fixed new workshop notifications: same approach as class notifications
  - Removed unused `LiveNotificationService` imports from admin_classes_management_screen and workshop_service
- 2026-02-14: Upload UX polish (mobile-only, minimal UI additions)
  - Gallery video upload: added "Cancel Upload" button to progress dialog, wired to UploadTask.cancel()
  - Online video upload: Cancel button changes to "Cancel Upload" during active upload, cancels the UploadTask
  - Both flows show "Upload cancelled" message instead of error when user cancels
  - Gallery upload: added `mounted` guards before Navigator.pop and ScaffoldMessenger after upload completes
  - Gallery progress listener: added NaN/infinity guard on progress value (totalBytes > 0 check + isFinite)
  - Progress dialog `updateProgress`: added safe clamp(0.0, 1.0) with isFinite guard
  - Gallery photo picks (gallery + camera): added `maxWidth: 1920, maxHeight: 1920, imageQuality: 85` for compression
- 2026-02-14: Upload data safety fixes (mobile-only, no UI/behavior changes)
  - Gallery upload: if Firestore write fails after Storage upload, the orphaned Storage file is automatically deleted (rollback)
  - Online video upload: if Firestore write fails after video/thumbnail upload, all uploaded Storage files are cleaned up (rollback)
  - Gallery single delete: now deletes the Firebase Storage file before removing the Firestore document
  - Gallery bulk delete: same Storage cleanup applied per item before Firestore doc deletion
- 2026-02-14: Upload reliability fixes (mobile-only, no UI/behavior changes)
  - Added `wakelock_plus` package to keep screen awake during video uploads, preventing iOS/Android background kill
  - Gallery upload: wakelock enabled only for video uploads, disabled in finally block (photos unaffected)
  - Online video upload: wakelock enabled when video file is being uploaded, disabled in finally block
  - Gallery upload: added `_isLoading` early-return guard at top of `_uploadMedia()` to prevent double-tap duplicate uploads
- 2026-02-14: Performance & stability optimizations (mobile-focused, no UI/behavior changes)
  - Fixed memory leaks: Added stream subscription tracking and cancellation in qr_scanner_screen, admin_online_management_screen, fcm_service (3 subscriptions), iap_service
  - Added `mounted` guards before 572+ setState calls that follow async operations across 24+ screen files to prevent setState-after-dispose crashes
  - Wired ErrorHandler utility into 70+ catch blocks across 11 critical files (login, payments, enrollment, attendance, profile) for Crashlytics reporting and user-friendly error messages
  - Integrated FCMService.dispose() and IapService.dispose() into app lifecycle cleanup in main.dart
- 2026-02-13: Security & architecture refactoring
  - Removed hardcoded admin/faculty keys from app_config.dart
  - Added Provider package with AppAuthProvider for centralized auth state
  - Wired MultiProvider into main.dart
  - Split home_screen.dart (11,466 lines) into 6 files using part/part of directives
  - Updated login_screen.dart and manage_role_keys_screen.dart to use Firestore-first key loading
  - Added environment SDK constraint to pubspec.yaml
- 2026-02-12: Initial Replit setup - adapted Flutter mobile app for web deployment
  - Lowered Dart SDK constraint from ^3.9.2 to ^3.8.0
  - Replaced deprecated `activeThumbColor` with `thumbColor` using `WidgetStatePropertyAll`
  - Stubbed `qr_code_scanner` for web compatibility
  - Added `kIsWeb` guards for FCM, Razorpay, and IAP services
  - Created Python HTTP server (`serve.py`) for serving on port 5000
