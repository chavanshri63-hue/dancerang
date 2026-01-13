/* eslint-disable @typescript-eslint/no-explicit-any */
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

/**
 * Cloud function to send FCM notifications when admin creates a notification
 * Triggers on: notifications/{notificationId} document creation
 */
export const sendAdminNotification = onDocumentCreated(
  {
    document: "notifications/{notificationId}",
    region: "asia-south1",
  },
  async (event) => {
    const notificationData = event.data?.data();
    if (!notificationData) {
      console.log("No notification data found");
      return;
    }

    // Skip scheduled notifications (they'll be processed later)
    if (notificationData.isScheduled === true) {
      console.log("Skipping scheduled notification");
      return;
    }

    const title = notificationData.title || "Notification";
    const body = notificationData.body || notificationData.message || "";
    const target = notificationData.target || "all";
    const type = notificationData.type || "general";
    const priority = notificationData.priority || "normal";

    const db = admin.firestore();
    let userQuery: admin.firestore.Query = db.collection("users");

    // Filter users based on target
    if (target === "students") {
      userQuery = userQuery.where("role", "==", "Student");
    } else if (target === "faculty") {
      userQuery = userQuery.where("role", "==", "Faculty");
    } else if (target === "subscribers") {
      // Get users with active subscriptions
      userQuery = userQuery.where("role", "==", "Student");
      // Note: Subscription check will be done per user
    } else if (target === "non_subscribers") {
      userQuery = userQuery.where("role", "==", "Student");
      // Note: Subscription check will be done per user
    }
    // else "all" - no filter

    try {
      const usersSnapshot = await userQuery.get();
      const batch = db.batch();
      let sentCount = 0;
      let skippedCount = 0;

      const fcmTokens: string[] = [];

      for (const userDoc of usersSnapshot.docs) {
        const userId = userDoc.id;
        const userData = userDoc.data();

        // Additional filtering for subscribers/non_subscribers
        if (target === "subscribers") {
          const subscriptionSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("subscriptions")
            .where("status", "==", "active")
            .where("endDate", ">", admin.firestore.Timestamp.now())
            .limit(1)
            .get();
          if (subscriptionSnapshot.empty) {
            skippedCount++;
            continue;
          }
        } else if (target === "non_subscribers") {
          const subscriptionSnapshot = await db
            .collection("users")
            .doc(userId)
            .collection("subscriptions")
            .where("status", "==", "active")
            .where("endDate", ">", admin.firestore.Timestamp.now())
            .limit(1)
            .get();
          if (!subscriptionSnapshot.empty) {
            skippedCount++;
            continue;
          }
        }

        // Get FCM token
        const fcmToken = userData.fcmToken as string | undefined;
        if (fcmToken) {
          fcmTokens.push(fcmToken);
        }

        // Save notification to user's notifications subcollection
        const userNotificationRef = db
          .collection("users")
          .doc(userId)
          .collection("notifications")
          .doc();
        batch.set(userNotificationRef, {
          title: title,
          body: body,
          message: body,
          type: type,
          priority: priority,
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          sentTo: target,
          data: {
            notificationId: event.data?.id,
          },
        });
        sentCount++;
      }

      // Commit user notifications to Firestore
      await batch.commit();

      // Send FCM messages in batches (FCM allows up to 500 tokens per batch)
      if (fcmTokens.length > 0) {
        const batchSize = 500;
        for (let i = 0; i < fcmTokens.length; i += batchSize) {
          const tokenBatch = fcmTokens.slice(i, i + batchSize);
          const message: admin.messaging.MulticastMessage = {
            notification: {
              title: title,
              body: body,
            },
            data: {
              type: type,
              priority: priority,
              target: target,
            },
            tokens: tokenBatch,
            android: {
              priority: priority === "high" ? "high" : "normal",
              notification: {
                channelId: "fcm_messages",
                sound: "default",
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                },
              },
            },
          };

          try {
            const response =
              await admin.messaging().sendEachForMulticast(message);
            console.log(
              `📱 FCM batch sent: ${response.successCount} success, ` +
              `${response.failureCount} failures`,
            );
          } catch (fcmError) {
            console.error("❌ Error sending FCM batch:", fcmError);
          }
        }
      }

      // Update notification status
      await event.data?.ref.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        sentCount: sentCount,
        skippedCount: skippedCount,
      });

      console.log(
        `✅ Notification sent: ${sentCount} users, ` +
        `${skippedCount} skipped, ${fcmTokens.length} FCM tokens`,
      );
    } catch (error) {
      console.error("❌ Error processing notification:", error);
      // Update notification status to failed
      try {
        await event.data?.ref.update({
          status: "failed",
          error: error instanceof Error ? error.message : String(error),
        });
      } catch (updateError) {
        console.error("❌ Error updating notification status:", updateError);
      }
    }
  },
);

