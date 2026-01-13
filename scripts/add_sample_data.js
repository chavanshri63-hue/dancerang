const { initializeApp } = require('firebase/app');
const { getFirestore, collection, addDoc, doc, setDoc } = require('firebase/firestore');

// Firebase config (replace with your config)
const firebaseConfig = {
  apiKey: "AIzaSyBXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  authDomain: "dancerang-733ea.firebaseapp.com",
  projectId: "dancerang-733ea",
  storageBucket: "dancerang-733ea.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abcdef123456789"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Sample subscription plans
const subscriptionPlans = {
  "basic_monthly": {
    "name": "Basic Monthly",
    "price": 299,
    "billingCycle": "monthly",
    "description": "Access to all basic dance videos",
    "priority": 1,
    "trialEnabled": true,
    "trialDays": 7,
    "active": true
  },
  "premium_monthly": {
    "name": "Premium Monthly",
    "price": 599,
    "billingCycle": "monthly",
    "description": "Access to all premium dance videos and live classes",
    "priority": 2,
    "trialEnabled": true,
    "trialDays": 14,
    "active": true
  },
  "pro_annual": {
    "name": "Pro Annual",
    "price": 4999,
    "billingCycle": "yearly",
    "description": "Full access to all content for 1 year",
    "priority": 3,
    "trialEnabled": true,
    "trialDays": 30,
    "active": true
  }
};

// Sample online videos
const onlineVideos = {
  "bollywood_basics": {
    "title": "Bollywood Basics - Step 1",
    "description": "Learn the fundamentals of Bollywood dance",
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
    "thumbnail": "https://images.unsplash.com/photo-1508700929628-666bc8bd84ea?w=400",
    "section": "Bollywood",
    "level": "Beginner",
    "duration": 300,
    "views": 0,
    "likes": 0,
    "isPaidContent": true,
    "isLive": false,
    "instructor": "Priya Sharma"
  },
  "hiphop_fundamentals": {
    "title": "Hip-Hop Fundamentals",
    "description": "Master the basics of hip-hop dance",
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
    "thumbnail": "https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400",
    "section": "Hip-Hop",
    "level": "Beginner",
    "duration": 450,
    "views": 0,
    "likes": 0,
    "isPaidContent": true,
    "isLive": false,
    "instructor": "Raj Kumar"
  },
  "contemporary_flow": {
    "title": "Contemporary Flow",
    "description": "Express yourself through contemporary dance",
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
    "thumbnail": "https://images.unsplash.com/photo-1547036967-23d11aacaee0?w=400",
    "section": "Contemporary",
    "level": "Intermediate",
    "duration": 600,
    "views": 0,
    "likes": 0,
    "isPaidContent": true,
    "isLive": false,
    "instructor": "Ananya Singh"
  },
  "kathak_basics": {
    "title": "Classical Kathak Basics",
    "description": "Learn traditional Kathak dance steps",
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
    "thumbnail": "https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=400",
    "section": "Classical",
    "level": "Beginner",
    "duration": 480,
    "views": 0,
    "likes": 0,
    "isPaidContent": true,
    "isLive": false,
    "instructor": "Dr. Meera Joshi"
  },
  "free_intro": {
    "title": "Free Introduction Video",
    "description": "Welcome to DanceRang - Free preview",
    "videoUrl": "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
    "thumbnail": "https://images.unsplash.com/photo-1518611012118-696088aa247a?w=400",
    "section": "Introduction",
    "level": "All",
    "duration": 120,
    "views": 0,
    "likes": 0,
    "isPaidContent": false,
    "isLive": false,
    "instructor": "DanceRang Team"
  }
};

async function addSampleData() {
  try {
    console.log('🚀 Adding sample subscription plans...');
    
    // Add subscription plans
    for (const [id, plan] of Object.entries(subscriptionPlans)) {
      await setDoc(doc(db, 'subscription_plans', id), plan);
      console.log(`✅ Added plan: ${plan.name}`);
    }
    
    console.log('🎬 Adding sample online videos...');
    
    // Add online videos
    for (const [id, video] of Object.entries(onlineVideos)) {
      await setDoc(doc(db, 'onlineVideos', id), video);
      console.log(`✅ Added video: ${video.title}`);
    }
    
    console.log('🎉 Sample data added successfully!');
    console.log('\n📋 Summary:');
    console.log(`- ${Object.keys(subscriptionPlans).length} subscription plans added`);
    console.log(`- ${Object.keys(onlineVideos).length} online videos added`);
    console.log('\n🔗 Test the subscription flow:');
    console.log('1. Open app and go to Online tab');
    console.log('2. Try to access paid videos (should show paywall)');
    console.log('3. Go to subscription plans and make a test payment');
    console.log('4. After payment, videos should be accessible');
    
  } catch (error) {
    console.error('❌ Error adding sample data:', error);
  }
}

// Run the script
addSampleData().then(() => {
  console.log('✅ Script completed');
  process.exit(0);
}).catch((error) => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
