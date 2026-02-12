/* eslint-disable @typescript-eslint/no-explicit-any */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

/**
 * Send a notification to a single user (FCM + in-app Firestore record).
 *
 * This is used for flows where an admin/faculty performs an action on behalf
 * of a student (e.g. cash approval). Client-side local notifications cannot
 * reach the student's device in that case.
 */
export const sendUserNotification = onCall(
  // Keep region consistent with client calls (asia-south1).
  {cors: true, region: "asia-south1"},
  async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const isAdmin = request.auth?.token?.admin === true;
    const isFaculty = request.auth?.token?.faculty === true;
    if (!isAdmin && !isFaculty) {
      throw new HttpsError("permission-denied", "Admin/Faculty only");
    }

    const userId = (request.data?.userId || "").toString().trim();
    const title = (request.data?.title || "Notification").toString();
    const body = (request.data?.body || request.data?.message || "").toString();
    const type = (request.data?.type || "general").toString();
    const priority = (request.data?.priority || "high").toString();
    const data = (request.data?.data && typeof request.data.data === "object") ?
      (request.data.data as Record<string, any>) : {};

    if (!userId) {
      throw new HttpsError("invalid-argument", "userId is required");
    }

    const db = admin.firestore();

    // Write to user's in-app notifications feed
    try {
      await db.collection("users").doc(userId).collection("notifications").add({
        title,
        body,
        message: body,
        type,
        priority,
        read: false,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data,
        meta: {
          source: "sendUserNotification",
          by: callerUid,
        },
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Failed to write notification: ${msg}`);
    }

    // Send FCM push if token exists
    try {
      const userDoc = await db.collection("users").doc(userId).get();
      const userData = userDoc.data() as any;
      const token = (userData?.fcmToken || "").toString().trim();
      if (!token) {
        return {ok: true, pushed: false, reason: "NO_FCM_TOKEN"};
      }

      await admin.messaging().send({
        token,
        notification: {title, body},
        data: {
          type,
          priority,
          userId,
        },
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
      });

      return {ok: true, pushed: true};
    } catch (e) {
      // If FCM fails, still keep in-app notification as the source of truth.
      return {ok: true, pushed: false, reason: "FCM_SEND_FAILED"};
    }
  },
);

