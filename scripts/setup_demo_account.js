const admin = require('firebase-admin');

// Initialize Firebase Admin
// Note: You need to download service account key from Firebase Console
// Go to: Project Settings > Service Accounts > Generate New Private Key
// Save it as: functions/serviceAccountKey.json
let serviceAccount;
try {
  serviceAccount = require('../functions/serviceAccountKey.json');
} catch (e) {
  console.error('❌ Error: serviceAccountKey.json not found!');
  console.log('\n📋 To fix this:');
  console.log('1. Go to Firebase Console > Project Settings > Service Accounts');
  console.log('2. Click "Generate New Private Key"');
  console.log('3. Save the file as: functions/serviceAccountKey.json');
  console.log('4. Run this script again\n');
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://dancerang-733ea-default-rtdb.firebaseio.com'
});

const db = admin.firestore();
const auth = admin.auth();

// Demo phone number (same as test phone number in Firebase Console)
const DEMO_PHONE = '+919999999999';
const DEMO_EMAIL = 'demo@dancerang.com';

async function setupDemoAccount() {
  try {
    console.log('🚀 Setting up demo account for App Store Review...\n');

    // Step 1: Create demo user in Firebase Auth (if not exists)
    console.log('📱 Step 1: Creating demo user in Firebase Auth...');
    let demoUser;
    try {
      // Try to get existing user by phone
      const users = await auth.listUsers();
      demoUser = users.users.find(u => u.phoneNumber === DEMO_PHONE);
      
      if (!demoUser) {
        // Create new user
        demoUser = await auth.createUser({
          phoneNumber: DEMO_PHONE,
          email: DEMO_EMAIL,
          displayName: 'Demo User',
          emailVerified: true,
        });
        console.log('✅ Demo user created in Firebase Auth');
      } else {
        console.log('✅ Demo user already exists in Firebase Auth');
      }
    } catch (error) {
      console.error('❌ Error creating demo user:', error.message);
      // Continue anyway - user might be created via phone auth
    }

    // Step 2: Create demo user profile in Firestore
    console.log('\n📝 Step 2: Creating demo user profile in Firestore...');
    const userId = demoUser?.uid || 'demo_user_id'; // Fallback if user creation failed
    
    const demoUserProfile = {
      uid: userId,
      phoneNumber: DEMO_PHONE,
      phone: DEMO_PHONE,
      name: 'Demo User',
      email: DEMO_EMAIL,
      role: 'Student', // Can be changed to 'Admin' or 'Faculty' for testing
      address: '123 Demo Street, Demo City, 123456',
      dob: '2000-01-01',
      bio: 'This is a demo account for App Store review',
      isActive: true,
      isDemoAccount: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(userId).set(demoUserProfile, { merge: true });
    console.log('✅ Demo user profile created in Firestore');

    // Step 3: Create sample classes
    console.log('\n🎓 Step 3: Creating sample classes...');
    const sampleClasses = [
      {
        name: 'Beginner Bollywood Dance',
        instructor: 'Priya Sharma',
        instructorId: 'instructor_1',
        date: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 7 days from now
        time: '10:00 AM',
        duration: 60,
        enrolledCount: 5,
        maxStudents: 20,
        currentBookings: 5,
        price: 500,
        category: 'Bollywood',
        level: 'Beginner',
        description: 'Learn the basics of Bollywood dance with fun and energetic moves',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        name: 'Hip-Hop Fundamentals',
        instructor: 'Raj Kumar',
        instructorId: 'instructor_2',
        date: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 10 days from now
        time: '6:00 PM',
        duration: 90,
        enrolledCount: 8,
        maxStudents: 25,
        currentBookings: 8,
        price: 600,
        category: 'Hip-Hop',
        level: 'Beginner',
        description: 'Master the fundamentals of hip-hop dance and street style',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        name: 'Contemporary Flow',
        instructor: 'Ananya Singh',
        instructorId: 'instructor_3',
        date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0], // 14 days from now
        time: '4:00 PM',
        duration: 75,
        enrolledCount: 3,
        maxStudents: 15,
        currentBookings: 3,
        price: 700,
        category: 'Contemporary',
        level: 'Intermediate',
        description: 'Express yourself through contemporary dance movements',
        isActive: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    for (const classData of sampleClasses) {
      const classRef = await db.collection('classes').add(classData);
      console.log(`✅ Created class: ${classData.name} (ID: ${classRef.id})`);
    }

    // Step 4: Create sample online videos
    console.log('\n🎬 Step 4: Creating sample online videos...');
    const sampleVideos = [
      {
        title: 'Welcome to DanceRang - Free Introduction',
        description: 'Get started with DanceRang and explore our dance classes',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?w=400',
        section: 'Introduction',
        level: 'All',
        duration: 120, // 2 minutes
        views: 0,
        likes: 0,
        isPaidContent: false, // Free for review
        isLive: false,
        instructor: 'DanceRang Team',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        title: 'Bollywood Basics - Step 1',
        description: 'Learn the fundamentals of Bollywood dance',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400',
        section: 'Bollywood',
        level: 'Beginner',
        duration: 300, // 5 minutes
        views: 0,
        likes: 0,
        isPaidContent: false, // Free for review
        isLive: false,
        instructor: 'Priya Sharma',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {
        title: 'Hip-Hop Fundamentals',
        description: 'Master the basics of hip-hop dance',
        videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
        thumbnailUrl: 'https://images.unsplash.com/photo-1547036967-23d11aacaee0?w=400',
        section: 'Hip-Hop',
        level: 'Beginner',
        duration: 450, // 7.5 minutes
        views: 0,
        likes: 0,
        isPaidContent: false, // Free for review
        isLive: false,
        instructor: 'Raj Kumar',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    ];

    for (const video of sampleVideos) {
      const videoRef = await db.collection('onlineVideos').add(video);
      console.log(`✅ Created video: ${video.title} (ID: ${videoRef.id})`);
    }

    // Step 5: Create sample subscription plans (if not exists)
    console.log('\n💳 Step 5: Checking subscription plans...');
    const plansSnapshot = await db.collection('subscription_plans').limit(1).get();
    if (plansSnapshot.empty) {
      const samplePlans = [
        {
          name: 'Basic Monthly',
          price: 299,
          billingCycle: 'monthly',
          description: 'Access to all basic dance videos',
          priority: 1,
          trialEnabled: true,
          trialDays: 7,
          active: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {
          name: 'Premium Monthly',
          price: 599,
          billingCycle: 'monthly',
          description: 'Access to all premium dance videos and live classes',
          priority: 2,
          trialEnabled: true,
          trialDays: 14,
          active: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      ];

      for (const plan of samplePlans) {
        const planRef = await db.collection('subscription_plans').add(plan);
        console.log(`✅ Created plan: ${plan.name} (ID: ${planRef.id})`);
      }
    } else {
      console.log('✅ Subscription plans already exist');
    }

    // Step 6: Create demo enrollment (optional - for testing)
    console.log('\n📚 Step 6: Creating demo enrollment...');
    const classesSnapshot = await db.collection('classes').limit(1).get();
    if (!classesSnapshot.empty) {
      const firstClass = classesSnapshot.docs[0];
      const enrollmentData = {
        userId: userId,
        classId: firstClass.id,
        className: firstClass.data().name,
        status: 'active',
        enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      
      await db.collection('users').doc(userId).collection('enrollments').doc(firstClass.id).set(enrollmentData);
      console.log(`✅ Created enrollment for class: ${firstClass.data().name}`);
    }

    console.log('\n🎉 Demo account setup completed successfully!');
    console.log('\n📋 Summary:');
    console.log(`- Demo user: ${DEMO_PHONE}`);
    console.log(`- Sample classes: ${sampleClasses.length}`);
    console.log(`- Sample videos: ${sampleVideos.length}`);
    console.log(`- Demo enrollment: Created`);
    console.log('\n🔗 Next Steps:');
    console.log('1. Go to Firebase Console > Authentication > Sign-in method > Phone');
    console.log('2. Scroll down to "Phone numbers for testing"');
    console.log('3. Add test number: +919999999999 with OTP: 123456');
    console.log('4. Test the demo login in your app');
    console.log('5. Add demo credentials to App Store Connect\n');

  } catch (error) {
    console.error('❌ Error setting up demo account:', error);
    process.exit(1);
  }
}

// Run the script
setupDemoAccount().then(() => {
  console.log('✅ Script completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
