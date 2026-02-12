# 🚀 Quick Setup Guide - Demo Account

## Option 1: Automatic Setup (Recommended)

### Step 1: Download Service Account Key

**Terminal mein ye command run karo:**
```bash
open https://console.firebase.google.com/project/dancerang-733ea/settings/serviceaccounts/adminsdk
```

Browser mein:
1. "Generate New Private Key" button click karo
2. "Generate Key" click karo
3. Downloaded JSON file ko save karo as: `functions/serviceAccountKey.json`

### Step 2: Run Setup Script

**Terminal mein ye command run karo:**
```bash
cd /Users/shreechavan/dancerang
node scripts/setup_demo_simple.js
```

✅ **Done!** Script automatically sab kuch setup kar dega.

---

## Option 2: Manual Setup (If script doesn't work)

### Step 1: Firebase Console mein Test Phone Number Add Karo

1. Open: https://console.firebase.google.com
2. Project select: `dancerang`
3. Authentication > Sign-in method > Phone
4. Scroll down to "Phone numbers for testing"
5. Add:
   - Phone: `+919999999999`
   - OTP: `123456`

### Step 2: Service Account Key Download

1. Firebase Console > Project Settings > Service Accounts
2. "Generate New Private Key" click karo
3. File save karo: `functions/serviceAccountKey.json`

### Step 3: Run Script

```bash
node scripts/setup_demo_simple.js
```

---

## What the Script Does:

✅ Creates demo user account
✅ Adds sample classes (2 classes)
✅ Adds sample videos (2 videos)
✅ Adds subscription plans
✅ Creates demo enrollment

---

## After Setup:

1. **Test Demo Login:**
   - App run karo: `flutter run`
   - Login screen pe "Demo Login (For Review)" button click karo
   - Auto login ho jayega

2. **App Store Connect:**
   - Demo credentials add karo:
     - Phone: `+919999999999`
     - OTP: `123456`

---

## Troubleshooting:

### Error: serviceAccountKey.json not found
**Solution:** Step 1 follow karo - service account key download karo

### Error: Permission denied
**Solution:** Check karo ki file sahi location mein hai: `functions/serviceAccountKey.json`

### Script runs but no data added
**Solution:** Firebase Console mein check karo ki Firestore rules allow kar rahe hain

---

## Quick Commands:

```bash
# Check if service account key exists
ls -la functions/serviceAccountKey.json

# Run setup script
node scripts/setup_demo_simple.js

# Check Firebase login
firebase projects:list
```

---

**Need Help?** Script automatically error messages dikhayega aur next steps bata dega!
