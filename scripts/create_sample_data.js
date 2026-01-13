const admin = require('firebase-admin');

// Initialize Firebase Admin
const serviceAccount = require('../functions/serviceAccountKey.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://dancerang-733ea-default-rtdb.firebaseio.com'
});

const db = admin.firestore();

// Sample subscription plans
const subscriptionPlans = [
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    name: 'Pro Annual',
    price: 4999,
    billingCycle: 'yearly',
    description: 'Full access to all content for 1 year',
    priority: 3,
    trialEnabled: true,
    trialDays: 30,
    active: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

// Sample online videos
const onlineVideos = [
  {
    title: 'Bollywood Basics - Step 1',
    description: 'Learn the fundamentals of Bollywood dance',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?w=400',
    section: 'Bollywood',
    level: 'Beginner',
    duration: 300, // 5 minutes
    views: 0,
    likes: 0,
    isPaidContent: true,
    isLive: false,
    instructor: 'Priya Sharma',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    title: 'Hip-Hop Fundamentals',
    description: 'Master the basics of hip-hop dance',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400',
    section: 'Hip-Hop',
    level: 'Beginner',
    duration: 450, // 7.5 minutes
    views: 0,
    likes: 0,
    isPaidContent: true,
    isLive: false,
    instructor: 'Raj Kumar',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    title: 'Contemporary Flow',
    description: 'Express yourself through contemporary dance',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1547036967-23d11aacaee0?w=400',
    section: 'Contemporary',
    level: 'Intermediate',
    duration: 600, // 10 minutes
    views: 0,
    likes: 0,
    isPaidContent: true,
    isLive: false,
    instructor: 'Ananya Singh',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    title: 'Classical Kathak Basics',
    description: 'Learn traditional Kathak dance steps',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400',
    section: 'Classical',
    level: 'Beginner',
    duration: 480, // 8 minutes
    views: 0,
    likes: 0,
    isPaidContent: true,
    isLive: false,
    instructor: 'Dr. Meera Joshi',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  },
  {
    title: 'Free Introduction Video',
    description: 'Welcome to DanceRang - Free preview',
    videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    thumbnail: 'https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400',
    section: 'Introduction',
    level: 'All',
    duration: 120, // 2 minutes
    views: 0,
    likes: 0,
    isPaidContent: false, // Free content
    isLive: false,
    instructor: 'DanceRang Team',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  }
];

async function createSampleData() {
  try {
    console.log('🚀 Creating sample subscription plans...');
    
    // Create subscription plans
    for (const plan of subscriptionPlans) {
      const docRef = await db.collection('subscription_plans').add(plan);
      console.log(`✅ Created plan: ${plan.name} (ID: ${docRef.id})`);
    }
    
    console.log('🎬 Creating sample online videos...');
    
    // Create online videos
    for (const video of onlineVideos) {
      const docRef = await db.collection('onlineVideos').add(video);
      console.log(`✅ Created video: ${video.title} (ID: ${docRef.id})`);
    }
    
    console.log('🎉 Sample data created successfully!');
    console.log('\n📋 Summary:');
    console.log(`- ${subscriptionPlans.length} subscription plans created`);
    console.log(`- ${onlineVideos.length} online videos created`);
    console.log('\n🔗 Test the subscription flow:');
    console.log('1. Open app and go to Online tab');
    console.log('2. Try to access paid videos (should show paywall)');
    console.log('3. Go to subscription plans and make a test payment');
    console.log('4. After payment, videos should be accessible');
    
  } catch (error) {
    console.error('❌ Error creating sample data:', error);
  }
}

// Run the script
createSampleData().then(() => {
  console.log('✅ Script completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
