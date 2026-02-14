/* eslint-disable @typescript-eslint/no-explicit-any */
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

/**
 * Notify all admin/faculty users when a new approval request is created.
 * Triggers on: approvals/{approvalId} document creation
 */
export const onApprovalCreated = onDocumentCreated(
  {
    document: "approvals/{approvalId}",
    region: "asia-south1",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    if (data.status !== "pending") return;

    const type = data.type || "request";
    const message = data.message || data.title || "New request";
    const amount = data.amount || "";

    let title = "📋 New Approval Request";
    let body = message;

    if (type === "cash_payment") {
      title = "💰 New Cash Payment Request";
      body = message || `₹${amount} - Pending approval`;
    }

    const db = admin.firestore();

    try {
      const adminsSnapshot = await db
        .collection("users")
        .where("role", "in", ["Admin", "Faculty"])
        .get();

      if (adminsSnapshot.empty) return;

      const batch = db.batch();
      const fcmTokens: string[] = [];

      for (const adminDoc of adminsSnapshot.docs) {
        const adminData = adminDoc.data();

        const notifRef = db
          .collection("users")
          .doc(adminDoc.id)
          .collection("notifications")
          .doc();
        batch.set(notifRef, {
          title,
          body,
          message: body,
          type: "admin_approval_request",
          priority: "high",
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: {
            approvalId: event.data?.id,
            approvalType: type,
            userId: data.user_id || "",
          },
        });

        const token = (adminData.fcmToken || "").toString().trim();
        if (token) fcmTokens.push(token);
      }

      await batch.commit();

      if (fcmTokens.length > 0) {
        try {
          await admin.messaging().sendEachForMulticast({
            notification: {title, body},
            data: {
              type: "admin_approval_request",
              priority: "high",
            },
            tokens: fcmTokens,
            android: {
              priority: "high",
              notification: {channelId: "fcm_messages", sound: "default"},
            },
            apns: {
              payload: {aps: {sound: "default", badge: 1}},
            },
          });
        } catch (fcmErr) {
          console.error("FCM send error (approvals):", fcmErr);
        }
      }

      console.log(
        `✅ Admin approval notification sent to ${adminsSnapshot.size} admins`,
      );
    } catch (error) {
      console.error("❌ Error sending admin approval notification:", error);
    }
  },
);

/**
 * Notify all admin/faculty users when a new studio booking is created.
 * Triggers on: studioBookings/{bookingId} document creation
 */
export const onStudioBookingCreated = onDocumentCreated(
  {
    document: "studioBookings/{bookingId}",
    region: "asia-south1",
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const name = data.name || "Student";
    const purpose = data.purpose || "Studio session";
    const duration = data.duration || 1;
    const dateField = data.date;
    let dateStr = "";
    if (dateField && typeof dateField.toDate === "function") {
      const d = dateField.toDate();
      dateStr = `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`;
    }
    const time = data.time || "";

    const title = "🏢 New Studio Booking";
    const body = `${name} booked ${duration}h` +
      (dateStr ? ` on ${dateStr}` : "") +
      (time ? ` at ${time}` : "") +
      ` - ${purpose}`;

    const db = admin.firestore();

    try {
      const adminsSnapshot = await db
        .collection("users")
        .where("role", "in", ["Admin", "Faculty"])
        .get();

      if (adminsSnapshot.empty) return;

      const batch = db.batch();
      const fcmTokens: string[] = [];

      for (const adminDoc of adminsSnapshot.docs) {
        const adminData = adminDoc.data();

        const notifRef = db
          .collection("users")
          .doc(adminDoc.id)
          .collection("notifications")
          .doc();
        batch.set(notifRef, {
          title,
          body,
          message: body,
          type: "new_studio_booking",
          priority: "high",
          read: false,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: {
            bookingId: event.data?.id,
            userId: data.userId || "",
            name: name,
            duration: duration,
          },
        });

        const token = (adminData.fcmToken || "").toString().trim();
        if (token) fcmTokens.push(token);
      }

      await batch.commit();

      if (fcmTokens.length > 0) {
        try {
          await admin.messaging().sendEachForMulticast({
            notification: {title, body},
            data: {
              type: "new_studio_booking",
              priority: "high",
            },
            tokens: fcmTokens,
            android: {
              priority: "high",
              notification: {channelId: "fcm_messages", sound: "default"},
            },
            apns: {
              payload: {aps: {sound: "default", badge: 1}},
            },
          });
        } catch (fcmErr) {
          console.error("FCM send error (studio booking):", fcmErr);
        }
      }

      console.log(
        `✅ Admin studio booking notification sent to ${adminsSnapshot.size} admins`,
      );
    } catch (error) {
      console.error("❌ Error sending studio booking notification:", error);
    }
  },
);
