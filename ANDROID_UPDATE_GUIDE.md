# Android App Update Guide

## 🔄 Future Updates Kaise Kare

### Step 1: Version Update Karo

**`pubspec.yaml` mein version badhao:**
```yaml
version: 1.0.0+1  # Current
version: 1.0.1+2  # Update (versionName+versionCode)
```

**Rules:**
- `versionName` (1.0.1): User ko dikhne wala version
- `versionCode` (+2): Har update pe +1 badhana hai (1, 2, 3, 4...)

**Example:**
- First release: `1.0.0+1`
- First update: `1.0.1+2` ya `1.0.0+2`
- Second update: `1.0.2+3` ya `1.0.0+3`

### Step 2: Code Changes Karo

App mein jo bhi changes chahiye, wo kar lo:
- New features
- Bug fixes
- UI improvements
- etc.

### Step 3: Release Build Banao

**Same keystore use hoga automatically:**
```bash
flutter build appbundle --release
```

**Important:** 
- ✅ Same keystore file use hoga (`android/upload-keystore.jks`)
- ✅ Same passwords use honge (`android/key.properties`)
- ✅ Kuch extra karna nahi padega

### Step 4: Play Store Pe Upload Karo

1. **Google Play Console** → App select karo
2. **Production** → **Create new release**
3. **AAB file upload** karo: `build/app/outputs/bundle/release/app-release.aab`
4. **Release notes** add karo (kya changes kiye)
5. **Review & publish**

## ⚠️ CRITICAL: Keystore Safety

### Agar Keystore Lost Ho Gaya?

❌ **App update nahi kar sakte!**
- Play Store sirf same signature accept karta hai
- Naya keystore = Naya app (update nahi, fresh app hoga)

### Backup Kaise Kare?

**Option 1: Cloud Backup (Recommended)**
```bash
# Google Drive, Dropbox, etc. pe upload karo
# Files to backup:
- android/upload-keystore.jks
- android/key.properties (passwords)
```

**Option 2: External Drive**
- USB drive pe copy karo
- Safe location pe store karo

**Option 3: Password Manager**
- Passwords ko password manager mein save karo
- Keystore file ko encrypted storage mein rakho

## 📝 Update Checklist

Har update ke pehle:

- [ ] `pubspec.yaml` mein version badhao
- [ ] Code changes test kar lo
- [ ] Release build banao: `flutter build appbundle --release`
- [ ] AAB file check karo: `build/app/outputs/bundle/release/app-release.aab`
- [ ] Play Store pe upload karo
- [ ] Release notes add karo

## 🔐 Current Keystore Info

**Location:** `android/upload-keystore.jks`  
**Passwords:** `android/key.properties` mein saved

**⚠️ IMPORTANT:** In files ko backup karo aur safe rakho!

## 🚀 Quick Update Commands

```bash
# 1. Version update (pubspec.yaml manually edit karo)
# 2. Build release
flutter build appbundle --release

# 3. AAB file location
# build/app/outputs/bundle/release/app-release.aab
```

## 📱 Testing Update

Agar pehle test karna ho:
```bash
# Release APK build karo (testing ke liye)
flutter build apk --release

# Device pe install karo
flutter install --release
```

## ❓ Common Questions

**Q: Har update pe naya keystore banana padega?**  
A: ❌ Nahi! Same keystore har baar use hoga automatically.

**Q: Version code kya hai?**  
A: Play Store ke liye unique number. Har update pe +1 badhana hai.

**Q: Keystore password bhool gaye?**  
A: `android/key.properties` file check karo, wahan saved hai.

**Q: Keystore file delete ho gaya?**  
A: Backup se restore karo. Agar backup nahi hai, to app update nahi kar sakte.

