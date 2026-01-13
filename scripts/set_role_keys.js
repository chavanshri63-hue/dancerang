const admin = require('firebase-admin');
const serviceAccount = require('../serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setRoleKeys() {
  try {
    console.log('🚀 Setting role keys in Firestore...');
    
    await db.collection('appSettings').doc('roleKeys').set({
      adminKey: 'ANUSHREE0918',
      facultyKey: 'DANCERANG5678',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: false });
    
    console.log('✅ Keys successfully set in Firestore!');
    console.log('');
    console.log('📋 Keys set:');
    console.log('   Admin Key: ANUSHREE0918');
    console.log('   Faculty Key: DANCERANG5678');
    console.log('');
    console.log('✅ Done! You can now login with these keys.');
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

setRoleKeys();

