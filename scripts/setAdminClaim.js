const admin = require('firebase-admin');

// Initialize Firebase Admin SDK using default credentials
admin.initializeApp({
  projectId: 'dancerang-733ea'
});

/**
 * Set admin custom claim for a user
 * @param {string} uid - User UID
 * @param {boolean} isAdmin - Whether user should be admin
 * @returns {Promise<void>}
 */
async function setAdminClaim(uid, isAdmin = true) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: isAdmin });
    console.log(`✅ Successfully set admin claim for user: ${uid}`);
    
    // Verify the claim was set
    const user = await admin.auth().getUser(uid);
    console.log(`📋 User ${uid} custom claims:`, user.customClaims);
  } catch (error) {
    console.error(`❌ Error setting admin claim for user ${uid}:`, error);
    throw error;
  }
}

/**
 * Remove admin custom claim for a user
 * @param {string} uid - User UID
 * @returns {Promise<void>}
 */
async function removeAdminClaim(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    console.log(`✅ Successfully removed admin claim for user: ${uid}`);
  } catch (error) {
    console.error(`❌ Error removing admin claim for user ${uid}:`, error);
    throw error;
  }
}

/**
 * Get user's custom claims
 * @param {string} uid - User UID
 * @returns {Promise<Object>}
 */
async function getUserClaims(uid) {
  try {
    const user = await admin.auth().getUser(uid);
    return user.customClaims || {};
  } catch (error) {
    console.error(`❌ Error getting claims for user ${uid}:`, error);
    throw error;
  }
}

/**
 * List all admin users
 * @returns {Promise<Array>}
 */
async function listAdminUsers() {
  try {
    const listUsersResult = await admin.auth().listUsers();
    const adminUsers = [];
    
    for (const userRecord of listUsersResult.users) {
      if (userRecord.customClaims && userRecord.customClaims.admin === true) {
        adminUsers.push({
          uid: userRecord.uid,
          email: userRecord.email,
          displayName: userRecord.displayName,
          customClaims: userRecord.customClaims
        });
      }
    }
    
    console.log('👑 Admin users:', adminUsers);
    return adminUsers;
  } catch (error) {
    console.error('❌ Error listing admin users:', error);
    throw error;
  }
}

// CLI usage
if (require.main === module) {
  const args = process.argv.slice(2);
  const command = args[0];
  const uid = args[1];
  
  switch (command) {
    case 'set':
      if (!uid) {
        console.error('❌ Please provide a UID: node setAdminClaim.js set <uid>');
        process.exit(1);
      }
      setAdminClaim(uid, true)
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
      break;
      
    case 'remove':
      if (!uid) {
        console.error('❌ Please provide a UID: node setAdminClaim.js remove <uid>');
        process.exit(1);
      }
      removeAdminClaim(uid)
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
      break;
      
    case 'get':
      if (!uid) {
        console.error('❌ Please provide a UID: node setAdminClaim.js get <uid>');
        process.exit(1);
      }
      getUserClaims(uid)
        .then(claims => {
          console.log(`📋 Claims for ${uid}:`, claims);
          process.exit(0);
        })
        .catch(() => process.exit(1));
      break;
      
    case 'list':
      listAdminUsers()
        .then(() => process.exit(0))
        .catch(() => process.exit(1));
      break;
      
    default:
      console.log(`
🔧 DanceRang Admin Claim Management

Usage:
  node setAdminClaim.js set <uid>     - Set admin claim for user
  node setAdminClaim.js remove <uid>  - Remove admin claim for user
  node setAdminClaim.js get <uid>     - Get user's custom claims
  node setAdminClaim.js list          - List all admin users

Examples:
  node setAdminClaim.js set abc123def456
  node setAdminClaim.js remove abc123def456
  node setAdminClaim.js get abc123def456
  node setAdminClaim.js list
      `);
      process.exit(0);
  }
}

module.exports = {
  setAdminClaim,
  removeAdminClaim,
  getUserClaims,
  listAdminUsers
};
