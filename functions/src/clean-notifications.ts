/* eslint-disable @typescript-eslint/no-explicit-any */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * Admin-only: Clean all notification-related data from Firestore
 * Deletes:
 * - users/{userId}/notifications subcollections
 * - notification_locks collection
 * - notifications collection (global)
 */
export const cleanNotificationData = onCall<{dryRun?: boolean}>(
  {cors: true},
  async (request) => {
    const isAdmin = request.auth?.token?.admin === true;
    if (!isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const dryRun = Boolean(request.data?.dryRun);
    const db = admin.firestore();
    let deletedCount = 0;

    try {
      // 1. Delete all user notification subcollections
      const usersSnapshot = await db.collection("users").select().get();
      for (const userDoc of usersSnapshot.docs) {
        const notificationsRef = db
          .collection("users")
          .doc(userDoc.id)
          .collection("notifications");

        const notificationsSnapshot = await notificationsRef.get();
        deletedCount += notificationsSnapshot.size;

        if (!dryRun) {
          const batch = db.batch();
          notificationsSnapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
          });
          await batch.commit();
        }
      }

      // 2. Delete notification_locks collection
      const locksSnapshot = await db.collection("notification_locks").get();
      deletedCount += locksSnapshot.size;

      if (!dryRun) {
        const batch = db.batch();
        locksSnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }

      // 3. Delete global notifications collection
      const globalNotificationsSnapshot =
        await db.collection("notifications").get();
      deletedCount += globalNotificationsSnapshot.size;

      if (!dryRun) {
        const batch = db.batch();
        globalNotificationsSnapshot.docs.forEach((doc) => {
          batch.delete(doc.ref);
        });
        await batch.commit();
      }

      const message = dryRun ?
        `Would delete ${deletedCount} notification documents` :
        `Deleted ${deletedCount} notification documents`;

      return {
        ok: true,
        deletedCount,
        dryRun,
        message: message,
      };
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Failed to clean notifications: ${msg}`);
    }
  },
);

