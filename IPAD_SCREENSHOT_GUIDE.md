# 📸 iPad Simulator Screenshot Guide

## Method 1: Keyboard Shortcut (Easiest) ⭐

1. **iPad Simulator mein app open karo**
2. **Keyboard shortcut press karo:**
   - Mac: `Cmd + S`
   - Ya `Cmd + Shift + 4` (full screen screenshot)
3. **Screenshot automatically save ho jayega**
4. **Location:** Desktop pe ya Downloads folder mein

---

## Method 2: Simulator Menu Se

1. **Simulator window pe click karo**
2. **Top menu bar mein:**
   - **Device** > **Screenshot** click karo
3. **Screenshot automatically capture ho jayega**
4. **Save location:** Desktop pe

---

## Method 3: Terminal Command Se

Terminal mein ye command run karo:

```bash
xcrun simctl io booted screenshot ~/Desktop/ipad-screenshot-$(date +%Y%m%d-%H%M%S).png
```

Ye command:
- Screenshot capture karega
- Desktop pe save karega
- Filename mein timestamp add karega

---

## Method 4: Simulator Toolbar Se

1. **Simulator window ke top pe toolbar dikhega**
2. **Screenshot icon** (camera icon) click karo
3. **Screenshot capture ho jayega**

---

## Screenshot Size Check

iPad Air 11-inch (M3) ke liye screenshot size:
- **Width:** 1668 pixels
- **Height:** 2388 pixels

Screenshot capture karne ke baad size check karo:
1. Screenshot pe **right-click** karo
2. **Get Info** select karo
3. Size check karo

---

## Multiple Screenshots Capture Karne Ke Liye

### Step 1: Important Screens Capture Karo
1. **Login Screen** - Demo login button dikh raha hai
2. **Home Screen** - Main dashboard
3. **Classes Screen** - Classes list
4. **Profile Screen** - User profile

### Step 2: Screenshots Organize Karo
Desktop pe folder banao:
```
iPad-Screenshots/
  ├── 01-login.png
  ├── 02-home.png
  ├── 03-classes.png
  └── 04-profile.png
```

---

## Quick Commands

### Single Screenshot:
```bash
xcrun simctl io booted screenshot ~/Desktop/ipad-screenshot.png
```

### Multiple Screenshots (with timestamp):
```bash
# Screenshot 1
xcrun simctl io booted screenshot ~/Desktop/ipad-01-login.png

# Screenshot 2 (after navigating)
xcrun simctl io booted screenshot ~/Desktop/ipad-02-home.png

# Screenshot 3
xcrun simctl io booted screenshot ~/Desktop/ipad-03-classes.png
```

---

## App Store Connect Ke Liye Screenshots

### Required Sizes:
- **iPad Pro 12.9":** 2048 x 2732 pixels
- **iPad Air 11":** 1668 x 2388 pixels (current simulator)

### Minimum Requirements:
- At least **3 screenshots** required
- First 3 screenshots will be shown on App Store
- Screenshots should show actual app UI (not splash/login screens)

---

## Tips:

1. ✅ **Best screenshots:**
   - Home screen (main features dikh rahe hain)
   - Classes screen (content visible hai)
   - Profile screen (user features)

2. ❌ **Avoid:**
   - Splash screen
   - Login screen (unless demo login button dikh raha hai)
   - Empty screens

3. 📱 **Quality:**
   - High resolution screenshots use karo
   - Clear and readable text
   - Proper UI elements visible

---

## Troubleshooting:

### Screenshot nahi capture ho raha?
- Simulator window active hai? (click karo)
- App properly loaded hai?
- Try: `Cmd + S` keyboard shortcut

### Screenshot size wrong?
- Simulator size check karo
- Settings > Display > Resolution check karo
- Correct iPad model select karo

---

**Best Method:** `Cmd + S` keyboard shortcut - sabse easy aur fast! 🚀
