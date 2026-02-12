# Firebase Demo Account Setup Guide

## Step 1: Add Test Phone Number in Firebase Console

1. **Open Firebase Console**: https://console.firebase.google.com
2. **Select Project**: `dancerang`
3. **Go to Authentication**:
   - Left sidebar se "Authentication" click karo
   - "Sign-in method" tab select karo
4. **Phone Provider**:
   - "Phone" provider pe click karo (already enabled hai)
   - Scroll down karo to "Phone numbers for testing" section
5. **Add Test Number**:
   - "Add phone number" button click karo
   - **Phone number**: `+919999999999`
   - **Verification code**: `123456`
   - "Add" button click karo

✅ **Done!** Test phone number add ho gaya.

---

## Step 2: Download Service Account Key

1. **Firebase Console** mein:
   - Left sidebar se ⚙️ **"Project Settings"** click karo
   - **"Service Accounts"** tab select karo
2. **Generate Key**:
   - "Generate New Private Key" button click karo
   - Dialog box mein "Generate Key" click karo
   - JSON file download ho jayegi
3. **Save File**:
   - Downloaded file ko rename karo: `serviceAccountKey.json`
   - File ko move karo: `functions/serviceAccountKey.json`
   - **Important**: Ye file git mein commit mat karo (security ke liye)

✅ **Done!** Service account key ready hai.

---

## Step 3: Run Demo Setup Script

Terminal mein ye commands run karo:

```bash
cd /Users/shreechavan/dancerang
node scripts/setup_demo_account.js
```

Script automatically:
- ✅ Demo user account create karega
- ✅ Sample classes add karega
- ✅ Sample videos add karega
- ✅ Subscription plans add karega
- ✅ Demo enrollment create karega

✅ **Done!** Demo data ready hai.

---

## Step 4: Test Demo Login

1. **App run karo**:
   ```bash
   flutter run
   ```

2. **Login Screen**:
   - "Demo Login (For Review)" button click karo
   - Role select karo (Student/Admin/Faculty)
   - Button click karo
   - Auto login ho jayega (OTP verification nahi chahiye)

✅ **Done!** Demo login working hai.

---

## Step 5: App Store Connect mein Demo Credentials Add Karo

1. **App Store Connect** open karo
2. **Your App** > **App Review Information**
3. **Demo Account** section:
   - **Username/Phone**: `+919999999999`
   - **Password/OTP**: `123456`
   - **Notes**: 
     ```
     Use "Demo Login (For Review)" button on login screen.
     Select role (Student/Admin/Faculty) and click button.
     No OTP verification needed.
     ```

✅ **Done!** App Store Connect ready hai.

---

## Troubleshooting

### Error: serviceAccountKey.json not found
- **Solution**: Step 2 follow karo - service account key download karo

### Error: Permission denied
- **Solution**: Service account key sahi location mein hai na? Check: `functions/serviceAccountKey.json`

### Test phone number add nahi ho raha
- **Solution**: Phone provider enabled hai na? Authentication > Sign-in method > Phone check karo

### Demo login button kaam nahi kar raha
- **Solution**: 
  1. Firebase Console mein test phone number add kiya hai na?
  2. App rebuild karo: `flutter clean && flutter run`

---

## Summary

✅ Test phone number: `+919999999999` (OTP: `123456`)
✅ Demo user: Auto-created in Firestore
✅ Sample data: Classes, Videos, Plans added
✅ Demo login: Working in app
✅ App Store Connect: Ready for submission

**Next**: App Store Connect mein business model questions ke answers add karo!
