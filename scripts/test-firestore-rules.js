const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { readFileSync } = require('fs');
const { join } = require('path');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'dancerang-test',
    firestore: {
      rules: readFileSync(join(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

describe('DanceRang Firestore Security Rules', () => {
  
  describe('Users Collection', () => {
    test('should allow users to read their own profile', async () => {
      const user = testEnv.authenticatedContext('user123');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('user123').set({
          uid: 'user123',
          name: 'Test User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        });
      });
      
      await assertSucceeds(
        user.firestore().collection('users').doc('user123').get()
      );
    });

    test('should deny users from reading other users profiles', async () => {
      const user = testEnv.authenticatedContext('user123');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('user456').set({
          uid: 'user456',
          name: 'Other User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        });
      });
      
      await assertFails(
        user.firestore().collection('users').doc('user456').get()
      );
    });

    test('should allow users to create their own profile', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      await assertSucceeds(
        user.firestore().collection('users').doc('user123').set({
          uid: 'user123',
          name: 'Test User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        })
      );
    });

    test('should prevent role escalation by non-admin users', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      // First create user as Student
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('user123').set({
          uid: 'user123',
          name: 'Test User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        });
      });
      
      // Try to escalate to Admin - should fail
      await assertFails(
        user.firestore().collection('users').doc('user123').update({
          role: 'Admin',
          updatedAt: new Date()
        })
      );
    });

    test('should allow admin to read any user profile', async () => {
      const admin = testEnv.authenticatedContext('admin123', { admin: true });
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('user123').set({
          uid: 'user123',
          name: 'Test User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        });
      });
      
      await assertSucceeds(
        admin.firestore().collection('users').doc('user123').get()
      );
    });
  });

  describe('Public Content Collections', () => {
    test('should allow everyone to read public content', async () => {
      const anonymous = testEnv.unauthenticatedContext();
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('classes').doc('class1').set({
          title: 'Dance Class',
          description: 'A great dance class',
          isActive: true,
          createdAt: new Date()
        });
      });
      
      await assertSucceeds(
        anonymous.firestore().collection('classes').doc('class1').get()
      );
    });

    test('should deny non-admin users from writing public content', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      await assertFails(
        user.firestore().collection('classes').doc('class1').set({
          title: 'Dance Class',
          description: 'A great dance class',
          isActive: true,
          createdAt: new Date()
        })
      );
    });

    test('should allow admin to write public content', async () => {
      const admin = testEnv.authenticatedContext('admin123', { admin: true });
      
      await assertSucceeds(
        admin.firestore().collection('classes').doc('class1').set({
          title: 'Dance Class',
          description: 'A great dance class',
          isActive: true,
          createdAt: new Date()
        })
      );
    });
  });

  describe('Registration Collections', () => {
    test('should allow users to create their own registrations', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      await assertSucceeds(
        user.firestore().collection('classRegistrations').doc('reg1').set({
          userId: 'user123',
          classId: 'class1',
          status: 'active',
          createdAt: new Date()
        })
      );
    });

    test('should deny users from creating registrations for others', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      await assertFails(
        user.firestore().collection('classRegistrations').doc('reg1').set({
          userId: 'user456', // Different user ID
          classId: 'class1',
          status: 'active',
          createdAt: new Date()
        })
      );
    });

    test('should allow users to read their own registrations', async () => {
      const user = testEnv.authenticatedContext('user123');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('classRegistrations').doc('reg1').set({
          userId: 'user123',
          classId: 'class1',
          status: 'active',
          createdAt: new Date()
        });
      });
      
      await assertSucceeds(
        user.firestore().collection('classRegistrations').doc('reg1').get()
      );
    });

    test('should deny users from reading others registrations', async () => {
      const user = testEnv.authenticatedContext('user123');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('classRegistrations').doc('reg1').set({
          userId: 'user456', // Different user ID
          classId: 'class1',
          status: 'active',
          createdAt: new Date()
        });
      });
      
      await assertFails(
        user.firestore().collection('classRegistrations').doc('reg1').get()
      );
    });
  });

  describe('App Settings', () => {
    test('should allow everyone to read app settings', async () => {
      const anonymous = testEnv.unauthenticatedContext();
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('appSettings').doc('maintenance').set({
          isMaintenanceMode: false,
          message: 'App is running normally'
        });
      });
      
      await assertSucceeds(
        anonymous.firestore().collection('appSettings').doc('maintenance').get()
      );
    });

    test('should deny non-admin users from writing app settings', async () => {
      const user = testEnv.authenticatedContext('user123');
      
      await assertFails(
        user.firestore().collection('appSettings').doc('maintenance').set({
          isMaintenanceMode: true,
          message: 'App is under maintenance'
        })
      );
    });

    test('should allow admin to write app settings', async () => {
      const admin = testEnv.authenticatedContext('admin123', { admin: true });
      
      await assertSucceeds(
        admin.firestore().collection('appSettings').doc('maintenance').set({
          isMaintenanceMode: true,
          message: 'App is under maintenance'
        })
      );
    });
  });

  describe('Authentication Requirements', () => {
    test('should deny unauthenticated users from creating user profiles', async () => {
      const anonymous = testEnv.unauthenticatedContext();
      
      await assertFails(
        anonymous.firestore().collection('users').doc('user123').set({
          uid: 'user123',
          name: 'Test User',
          role: 'Student',
          phone: '+1234567890',
          address: '123 Test St',
          isActive: true,
          createdAt: new Date(),
          lastLogin: new Date()
        })
      );
    });

    test('should deny unauthenticated users from creating registrations', async () => {
      const anonymous = testEnv.unauthenticatedContext();
      
      await assertFails(
        anonymous.firestore().collection('classRegistrations').doc('reg1').set({
          userId: 'user123',
          classId: 'class1',
          status: 'active',
          createdAt: new Date()
        })
      );
    });
  });
});

// Run tests
if (require.main === module) {
  const { runTests } = require('@firebase/rules-unit-testing');
  runTests();
}
