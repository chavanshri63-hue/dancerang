# DanceRang - Dance Studio Management App

## Overview
DanceRang is a comprehensive dance studio management Flutter application built for students, faculty, and administrators. It uses Firebase for backend services including authentication, Firestore database, Cloud Functions, Storage, and Analytics.

## Project Architecture
- **Framework**: Flutter (Dart) with web support
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Storage, Analytics, Messaging)
- **Payment**: Razorpay integration (mobile-only)
- **Build**: Flutter web build served via Python HTTP server

## Project Structure
- `lib/` - Main Dart source code
  - `main.dart` - App entry point with Firebase initialization
  - `screens/` - UI screens (login, home, admin dashboards, etc.)
  - `services/` - Business logic services (payment, attendance, notifications, etc.)
  - `models/` - Data models
  - `widgets/` - Reusable UI components
  - `config/` - App configuration
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

## Web Compatibility Notes
- `qr_code_scanner` replaced with local stub (`lib/utils/qr_stub.dart`) - QR scanning is mobile-only
- `razorpay_flutter` guarded with `kIsWeb` check - payments are mobile-only
- Firebase Messaging (FCM) guarded with `kIsWeb` - push notifications not supported on web in this environment
- `in_app_purchase` lazy-loaded to avoid web initialization errors
- SDK constraint relaxed to `^3.8.0` for compatibility with available Flutter SDK

## Recent Changes
- 2026-02-12: Initial Replit setup - adapted Flutter mobile app for web deployment
  - Lowered Dart SDK constraint from ^3.9.2 to ^3.8.0
  - Replaced deprecated `activeThumbColor` with `thumbColor` using `WidgetStatePropertyAll`
  - Stubbed `qr_code_scanner` for web compatibility
  - Added `kIsWeb` guards for FCM, Razorpay, and IAP services
  - Created Python HTTP server (`serve.py`) for serving on port 5000
