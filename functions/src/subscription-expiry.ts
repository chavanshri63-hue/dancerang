import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

/**
 * Send expiry notification to user
 * @param {string} userId - User ID
 * @param {any} subscriptionData - Subscription data
 */
async function sendExpiryNotification(
  userId: string,
  subscriptionData: unknown
) {
  try {
    const db = admin.firestore();

    // Check if notification already sent today
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStart = admin.firestore.Timestamp.fromDate(today);

    const notificationCheck = await db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .where("type", "==", "subscription_expired")
      .where("data.planId", "==", (subscriptionData as any)?.planId)
      .where("createdAt", ">", todayStart)
      .limit(1)
      .get();

    if (!notificationCheck.empty) {
      console.log(`⏭️  Duplicate notification skipped for user: ${userId}`);
      return; // Already sent today
    }

    await db.collection("users").doc(userId)
      .collection("notifications").add({
        title: "Subscription Expired",
        body: "Your subscription has expired. " +
        "Renew to continue accessing premium content.",
        message: "Your subscription has expired. " +
        "Renew to continue accessing premium content.",
        type: "subscription_expired",
        priority: "high",
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          planId: (subscriptionData as any)?.planId,
          action: "renew_subscription",
        },
      });

    console.log(`📱 Sent expiry notification to user: ${userId}`);
  } catch (error) {
    console.error(`❌ Error sending expiry notification to ${userId}:`, error);
  }
}

/**
 * Manual function to check expired subscriptions (for testing)
 */
export const checkExpiredSubscriptionsManual = functions
  .https.onCall(async (data: any, context: any) => {
    // Only allow admin users
    if (!context.auth?.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admin users can trigger manual expiry check"
      );
    }

    console.log("🔄 Manual subscription expiry check triggered by admin");

    try {
      const db = admin.firestore();
      const now = admin.firestore.Timestamp.now();

      const expiredSubscriptions = await db
        .collection("subscriptions")
        .where("status", "==", "active")
        .where("endDate", "<", now)
        .get();

      console.log(`📊 Found ${expiredSubscriptions.docs.length} ` +
        "expired subscriptions");

      const batch = db.batch();
      let expiredCount = 0;

      for (const doc of expiredSubscriptions.docs) {
        const data = doc.data();
        const userId = data.userId;
        const planId = data.planId;

        try {
          // Update global subscription
          batch.update(doc.ref, {
            status: "expired",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Update user subscription
          const userSubscriptions = await db
            .collection("users")
            .doc(userId)
            .collection("subscriptions")
            .where("planId", "==", planId)
            .where("status", "==", "active")
            .get();

          for (const userSub of userSubscriptions.docs) {
            batch.update(userSub.ref, {
              status: "expired",
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }

          // Send notification
          await sendExpiryNotification(userId, data);

          expiredCount++;
        } catch (error) {
          console.error(`❌ Error expiring subscription ${doc.id}:`, error);
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
      }

      return {
        success: true,
        expiredCount,
        message: `Successfully expired ${expiredCount} subscriptions`,
      };
    } catch (error) {
      console.error("❌ Error in manual subscription expiry check:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Error checking expired subscriptions"
      );
    }
  });
