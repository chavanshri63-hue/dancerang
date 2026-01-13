const admin = require('firebase-admin');

// Initialize Firebase Admin using default credentials
admin.initializeApp({
  projectId: 'dancerang-733ea'
});

async function setRazorpayKey() {
  try {
    const db = admin.firestore();
    await db.collection('appSettings').doc('razorpay').set({
      keyId: 'rzp_live_RPoheZY7Cu9bZU',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
    
    console.log('✅ Razorpay key set successfully in Firestore');
    console.log('📍 Path: appSettings/razorpay');
    console.log('🔑 KeyId: rzp_live_RPoheZY7Cu9bZU');
  } catch (error) {
    console.error('❌ Error setting Razorpay key:', error);
  } finally {
    process.exit(0);
  }
}

setRazorpayKey();
