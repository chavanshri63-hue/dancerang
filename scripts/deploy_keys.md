# Deploy Role Keys to Firestore

## Method 1: Automatic (Recommended)
Just run the app once - keys will be automatically set in Firestore on app startup.

## Method 2: Manual via Firebase Console
1. Go to Firebase Console: https://console.firebase.google.com/project/dancerang-733ea/firestore
2. Navigate to: appSettings > roleKeys
3. Create/Update document with:
   - adminKey: "ANUSHREE0918"
   - facultyKey: "DANCERANG5678"
   - updatedAt: (server timestamp)

## Method 3: Using Flutter App
Run the app and the initialization code in main.dart will automatically set the keys.
