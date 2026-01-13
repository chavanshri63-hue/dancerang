# Android Release Build Setup

## ✅ Setup Complete!

Android release signing has been configured. You can now build release APKs and AABs.

## 📦 Build Commands

### Build Release APK
```bash
flutter build apk --release
```

### Build Release App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

### Build Release APK (Split by ABI - smaller size)
```bash
flutter build apk --split-per-abi --release
```

## 🔐 Keystore Information

**Location:** `android/upload-keystore.jks`  
**Alias:** `upload`  
**Passwords:** Saved in `android/key.properties` (DO NOT commit to git)

## ⚠️ Important Notes

1. **Backup your keystore!** If you lose `upload-keystore.jks`, you won't be able to update your app on Play Store.

2. **Keep passwords safe!** The passwords are stored in `android/key.properties` which is git-ignored.

3. **Never commit keystore to git!** The keystore file is already in `.gitignore`.

## 🔄 If You Need to Recreate Keystore

Run the setup script again:
```bash
cd android
./create-keystore.sh
```

## 📱 Testing Release Build

You can test the release build on a device:
```bash
flutter install --release
```

## 🚀 Play Store Upload

Once you build the AAB, upload it to Google Play Console:
1. Go to Google Play Console
2. Create a new app or select existing app
3. Go to "Production" → "Create new release"
4. Upload the AAB file from `build/app/outputs/bundle/release/app-release.aab`

