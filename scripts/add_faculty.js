// Simple script to add faculty users to Firestore
// Run with: node scripts/add_faculty.js

const admin = require('firebase-admin');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'dancerang-733ea'
  });
}

const db = admin.firestore();

async function addFacultyUsers() {
  try {
    console.log('🚀 Adding faculty users...');
    
    // Faculty 1
    const faculty1 = {
      uid: 'faculty_001',
      name: 'John Doe',
      phone: '+1234567890',
      role: 'faculty',
      address: '123 Faculty Street, Mumbai',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('users').doc('faculty_001').set(faculty1);
    console.log('✅ Added faculty: John Doe');
    
    // Faculty 2
    const faculty2 = {
      uid: 'faculty_002',
      name: 'Jane Smith',
      phone: '+1234567891',
      role: 'faculty',
      address: '456 Faculty Avenue, Delhi',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('users').doc('faculty_002').set(faculty2);
    console.log('✅ Added faculty: Jane Smith');
    
    // Faculty 3
    const faculty3 = {
      uid: 'faculty_003',
      name: 'Mike Johnson',
      phone: '+1234567892',
      role: 'faculty',
      address: '789 Dance Lane, Bangalore',
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('users').doc('faculty_003').set(faculty3);
    console.log('✅ Added faculty: Mike Johnson');
    
    console.log('🎉 All faculty users added successfully!');
    console.log('📱 Now test the dropdown in the app - it should show 3 faculty members');
    
  } catch (error) {
    console.error('❌ Error adding faculty users:', error);
  } finally {
    process.exit(0);
  }
}

addFacultyUsers();
