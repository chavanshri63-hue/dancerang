// Simple script to setup demo data using Firebase Admin SDK
// This script will work if serviceAccountKey.json exists in functions/ folder

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

console.log('🚀 Starting demo account setup...\n');

// Check if service account key exists
const serviceAccountPath = path.join(__dirname, '../functions/serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.log('❌ ERROR: serviceAccountKey.json not found!\n');
  console.log('📋 Please follow these steps:\n');
  console.log('1. Go to: https://console.firebase.google.com');
  console.log('2. Select project: dancerang');
  console.log('3. Click ⚙️ Project Settings (top left)');
  console.log('4. Go to "Service Accounts" tab');
  console.log('5. Click "Generate New Private Key"');
  console.log('6. Save the file as: functions/serviceAccountKey.json\n');
  console.log('After saving the file, run this script again:\n');
  console.log('   node scripts/setup_demo_simple.js\n');
  process.exit(1);
}

// Load service account key
let serviceAccount;
try {
  serviceAccount = require(serviceAccountPath);
  console.log('✅ Service account key loaded\n');
} catch (e) {
  console.error('❌ Error loading service account key:', e.message);
  process.exit(1);
}

// Initialize Firebase Admin
try {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://dancerang-733ea-default-rtdb.firebaseio.com'
  });
  console.log('✅ Firebase Admin initialized\n');
} catch (e) {
  console.error('❌ Error initializing Firebase:', e.message);
  process.exit(1);
}

const db = admin.firestore();
const auth = admin.auth();

const DEMO_PHONE = '+919999999999';
const DEMO_EMAIL = 'demo@dancerang.com';

async function setupDemo() {
  try {
    console.log('📱 Step 1/6: Setting up demo user...');
    
    // Create or get demo user
    let demoUser;
    try {
      const users = await auth.listUsers(1000);
      demoUser = users.users.find(u => u.phoneNumber === DEMO_PHONE || u.email === DEMO_EMAIL);
      
      if (!demoUser) {
        demoUser = await auth.createUser({
          phoneNumber: DEMO_PHONE,
          email: DEMO_EMAIL,
          displayName: 'Demo User',
          emailVerified: true,
        });
        console.log('   ✅ Demo user created in Firebase Auth');
      } else {
        console.log('   ✅ Demo user already exists');
      }
    } catch (error) {
      console.log('   ⚠️  Note: User creation skipped (may need manual setup)');
      demoUser = { uid: 'demo_user_' + Date.now() };
    }

    const userId = demoUser.uid;
    console.log(`   📝 User ID: ${userId}\n`);

    console.log('📝 Step 2/6: Creating user profile...');
    await db.collection('users').doc(userId).set({
      uid: userId,
      phoneNumber: DEMO_PHONE,
      phone: DEMO_PHONE,
      name: 'Demo User',
      email: DEMO_EMAIL,
      role: 'Student',
      address: '123 Demo Street, Demo City',
      isActive: true,
      isDemoAccount: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('   ✅ User profile created\n');

    console.log('🎓 Step 3/6: Creating sample classes...');
    const classes = [
      {
        name: 'Beginner Bollywood Dance',
        instructor: 'Priya Sharma',
        date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        time: '10:00 AM',
        duration: 60,
        enrolledCount: 5,
        maxStudents: 20,
        currentBookings: 5,
        price: 500,
        category: 'Bollywood',
        level: 'Beginner',
        description: 'Learn the basics of Bollywood dance',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        name: 'Hip-Hop Fundamentals',
        instructor: 'Raj Kumar',
        date: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
        time: '6:00 PM',
        duration: 90,
        enrolledCount: 8,
        maxStudents: 25,
        currentBookings: 8,
        price: 600,
        category: 'Hip-Hop',
        level: 'Beginner',
        description: 'Master hip-hop dance fundamentals',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    for (const classData of classes) {
      await db.collection('classes').add(classData);
      console.log(`   ✅ Created: ${classData.name}`);
    }
    console.log('');

    console.log('🎬 Step 4/6: Creating sample videos...');
    const videos = [
      {
        title: 'Welcome to DanceRang',
        description: 'Get started with DanceRang',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?w=400',
        section: 'Introduction',
        level: 'All',
        duration: 120,
        isPaidContent: false,
        instructor: 'DanceRang Team',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        title: 'Bollywood Basics',
        description: 'Learn Bollywood dance basics',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400',
        section: 'Bollywood',
        level: 'Beginner',
        duration: 300,
        isPaidContent: false,
        instructor: 'Priya Sharma',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    for (const video of videos) {
      await db.collection('onlineVideos').add(video);
      console.log(`   ✅ Created: ${video.title}`);
    }
    console.log('');

    console.log('💳 Step 5/6: Checking subscription plans...');
    const plansCheck = await db.collection('subscription_plans').limit(1).get();
    if (plansCheck.empty) {
      const plans = [
        {
          name: 'Basic Monthly',
          price: 299,
          billingCycle: 'monthly',
          description: 'Access to basic dance videos',
          active: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      ];
      for (const plan of plans) {
        await db.collection('subscription_plans').add(plan);
        console.log(`   ✅ Created: ${plan.name}`);
      }
    } else {
      console.log('   ✅ Plans already exist');
    }
    console.log('');

    console.log('📚 Step 6/6: Creating demo enrollment...');
    const classesSnapshot = await db.collection('classes').limit(1).get();
    if (!classesSnapshot.empty) {
      const firstClass = classesSnapshot.docs[0];
      await db.collection('users').doc(userId).collection('enrollments').doc(firstClass.id).set({
        userId: userId,
        classId: firstClass.id,
        className: firstClass.data().name,
        status: 'active',
        enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`   ✅ Enrollment created for: ${firstClass.data().name}`);
    }
    console.log('');

    console.log('🎉 SUCCESS! Demo account setup completed!\n');
    console.log('📋 Summary:');
    console.log(`   • Demo Phone: ${DEMO_PHONE}`);
    console.log(`   • Demo Email: ${DEMO_EMAIL}`);
    console.log(`   • Classes: ${classes.length}`);
    console.log(`   • Videos: ${videos.length}`);
    console.log(`   • User ID: ${userId}\n`);
    console.log('⚠️  IMPORTANT: Add test phone number in Firebase Console:');
    console.log('   1. Go to: https://console.firebase.google.com');
    console.log('   2. Authentication > Sign-in method > Phone');
    console.log('   3. Scroll to "Phone numbers for testing"');
    console.log('   4. Add: +919999999999 with OTP: 123456\n');

  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

setupDemo().then(() => {
  process.exit(0);
}).catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
