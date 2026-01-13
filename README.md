## Razorpay Payments (Functions + Flutter)

### Backend config (Firebase Functions)

1) Set Razorpay LIVE keys in functions config (no hardcoding):

```bash
firebase functions:config:set razorpay.key_id="rzp_live_xxxxxxxxx" razorpay.key_secret="xxxxxxxxxxxx"
```

2) Deploy only the payments function (asia-south1) if needed:

```bash
cd functions
npm run deploy:payments
```

3) View logs while testing:

```bash
firebase functions:log --only createRazorpayOrderAsia
```

The callable name is `createRazorpayOrderAsia` and runs in region `asia-south1`.

# dancerang

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
