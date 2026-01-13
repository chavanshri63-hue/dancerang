const admin = require('firebase-admin');

// Initialize Firebase Admin using default credentials
admin.initializeApp({
  projectId: 'dancerang-733ea'
});

const db = admin.firestore();

// Sample subscription plans
const subscriptionPlans = [
  {
    name: 'Basic Plan',
    price: 299,
    billingCycle: 'monthly',
    description: 'Access to basic dance videos and tutorials',
    priority: 3,
    trialEnabled: true,
    trialDays: 7,
    active: true,
    features: [
      'Access to basic videos',
      'Download 5 videos offline',
      'Basic support'
    ]
  },
  {
    name: 'Premium Plan',
    price: 599,
    billingCycle: 'monthly',
    description: 'Full access to all premium content and live classes',
    priority: 1,
    trialEnabled: true,
    trialDays: 14,
    active: true,
    features: [
      'Access to all videos',
      'Unlimited downloads',
      'Live streaming access',
      'Priority support',
      'Advanced analytics'
    ]
  },
  {
    name: 'Pro Plan',
    price: 999,
    billingCycle: 'monthly',
    description: 'Everything in Premium plus exclusive content and personal coaching',
    priority: 2,
    trialEnabled: true,
    trialDays: 7,
    active: true,
    features: [
      'Everything in Premium',
      'Exclusive content',
      'Personal coaching sessions',
      'Custom workout plans',
      '24/7 support'
    ]
  },
  {
    name: 'Annual Premium',
    price: 5999,
    billingCycle: 'annual',
    description: 'Premium plan with 2 months free (₹500/month)',
    priority: 1,
    trialEnabled: true,
    trialDays: 30,
    active: true,
    features: [
      'Everything in Premium',
      '2 months free',
      'Exclusive annual content',
      'Priority booking',
      'Free merchandise'
    ]
  }
];

async function createSubscriptionPlans() {
  try {
    console.log('🚀 Creating subscription plans...');
    
    const batch = db.batch();
    
    for (const plan of subscriptionPlans) {
      const planRef = db.collection('subscription_plans').doc();
      batch.set(planRef, {
        ...plan,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    console.log('✅ Subscription plans created successfully!');
    
    // List created plans
    const plansSnapshot = await db.collection('subscription_plans').get();
    console.log('\n📋 Created Plans:');
    plansSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`- ${data.name}: ₹${data.price}/${data.billingCycle}`);
    });
    
  } catch (error) {
    console.error('❌ Error creating subscription plans:', error);
  }
}

// Run the script
createSubscriptionPlans().then(() => {
  console.log('\n🎉 Script completed!');
  process.exit(0);
}).catch(error => {
  console.error('❌ Script failed:', error);
  process.exit(1);
});
