/* eslint-disable @typescript-eslint/no-explicit-any */
import * as functionsV1 from "firebase-functions/v1";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Minimal callable in asia-south1 to ensure deployment/name match
export const createRazorpayOrder = functionsV1
  .region("asia-south1")
  .https.onCall(async (data: any, ctx: functionsV1.https.CallableContext) => {
    try {
      if (!ctx.auth?.uid) {
        throw new Error("UNAUTHENTICATED");
      }

      const amount = Number(data?.amount);
      const receipt = String(data?.receipt ?? `rcpt_${Date.now()}`);
      if (!Number.isFinite(amount) || amount < 100) {
        throw new Error("INVALID_AMOUNT");
      }

      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const Razorpay = require("razorpay");
      const rzCfg = functionsV1.config().razorpay as
        | {key_id?: string; key_secret?: string}
        | undefined;
      const keyId = rzCfg?.key_id as string | undefined;
      const keySecret = rzCfg?.key_secret as string | undefined;
      if (!keyId || !keySecret) {
        throw new Error("MISSING_KEYS");
      }

      const creds = {key_id: keyId, key_secret: keySecret};
      const rp = new Razorpay(creds);
      const order = await rp.orders.create({
        amount,
        currency: "INR",
        receipt,
        payment_capture: 1,
      });

      return {
        ok: true,
        orderId: String(order.id),
        amount: Number(order.amount),
        currency: String(order.currency || "INR"),
        receipt: String(order.receipt || receipt),
      };
    } catch (err: any) {
      // eslint-disable-next-line no-console
      const payload = {
        message: err?.message,
        code: err?.error?.code,
        details: err?.error || err,
      };
      console.error(
        "createRazorpayOrder error",
        payload,
      );
      throw new functionsV1.https.HttpsError(
        "internal",
        "CREATE_ORDER_FAILED",
        {
          message: err?.message ?? "Unknown error",
          code: err?.error?.code ?? null,
        },
      );
    }
  });


// Confirm Razorpay payment and fulfill order
export const confirmRazorpayPayment = functionsV1
  .region("asia-south1")
  .https.onCall(async (
    data: any,
    ctx: functionsV1.https.CallableContext,
  ) => {
    try {
      const uid = ctx.auth?.uid;
      if (!uid) {
        throw new functionsV1.https.HttpsError(
          "unauthenticated",
          "UNAUTHENTICATED",
        );
      }

      const orderId = String(data?.orderId || "").trim();
      const paymentId = String(data?.paymentId || "").trim();
      const signature = String(data?.signature || "").trim();
      const classId = String(data?.classId || "").trim();
      const workshopId = String(data?.workshopId || "").trim();
      const bookingId = String(data?.bookingId || "").trim();
      const studioBookingId = String(data?.studioBookingId || "").trim();
      const userId = String(data?.userId || uid).trim();
      const amount = Number(data?.amount || 0);
      const razorpayPaymentId = String(
        data?.razorpayPaymentId || paymentId
      ).trim();
      const razorpayOrderId = String(
        data?.razorpayOrderId || orderId
      ).trim();
      // const itemType = String(data?.itemType || "class").trim();

      const subscriptionId = String(data?.subscriptionId || "").trim();

      if (
        !orderId ||
        !paymentId ||
        !signature ||
        !userId ||
        !Number.isFinite(amount) ||
        amount <= 0 ||
        (!classId && !workshopId && !bookingId && !studioBookingId &&
          !subscriptionId)
      ) {
        throw new functionsV1.https.HttpsError(
          "invalid-argument",
          "MISSING_OR_INVALID_FIELDS",
        );
      }

      const itemId = classId || workshopId || bookingId || studioBookingId ||
        subscriptionId;
      const reqType = String(
        data?.itemType || data?.paymentType || "class",
      ).toLowerCase();
      const itemType = reqType === "workshop" ? "workshop" :
        reqType === "event_choreography" ? "event_choreography" :
          reqType === "studio_booking" ? "studio_booking" :
            reqType === "subscription" ? "subscription" : "class";
      const isWorkshop = itemType === "workshop";
      const isEventChoreography = itemType === "event_choreography";
      const isStudioBooking = itemType === "studio_booking";
      const isOnlineSubscription = itemType === "subscription";

      const keySecret = (
        functionsV1.config().razorpay as {key_secret?: string} | undefined
      )?.key_secret;
      if (!keySecret) {
        throw new functionsV1.https.HttpsError(
          "failed-precondition",
          "MISSING_KEYS",
        );
      }

      // Verify signature using key_secret
      const body = `${orderId}|${paymentId}`;
      const expected = crypto
        .createHmac("sha256", keySecret)
        .update(body)
        .digest("hex");
      const valid = expected === signature;
      if (!valid) {
        throw new functionsV1.https.HttpsError(
          "permission-denied",
          "INVALID_SIGNATURE",
        );
      }

      const db = admin.firestore();
      const paymentRef = db.collection("payments").doc(paymentId);
      // Canonical collections: enrollments (consistent spelling)
      const globalEnrollRef = db.collection("enrollments").doc(paymentId);
      const userEnrollRef = db
        .collection("users")
        .doc(userId)
        .collection("enrollments")
        .doc(itemId);
      const itemRef = db
        .collection(
          isWorkshop ? "workshops" :
            isEventChoreography ? "eventChoreoBookings" :
              isStudioBooking ? "studioBookings" : "classes"
        )
        .doc(itemId);
      const legacyEnrollRef = db
        .collection(isWorkshop ? "workshop_enrollments" : "class_enrollments")
        .doc(`${userId}_${itemId}_${paymentId}`);

      // Get item title
      const itemSnap = await itemRef.get();
      if (!itemSnap.exists) {
        throw new functionsV1.https.HttpsError(
          "not-found",
          "ITEM_NOT_FOUND",
        );
      }
      const itemData = (itemSnap.data() || {}) as Record<string, unknown>;
      const title = isWorkshop ?
        ((itemData?.title as string) || (itemData?.name as string) || "") :
        isEventChoreography ?
          ((itemData?.title as string) || (itemData?.name as string) || "") :
          isStudioBooking ?
            ((itemData?.title as string) || (itemData?.name as string) || "") :
            ((itemData?.name as string) || (itemData?.title as string) || "");

      // Get numberOfSessions from class (for classes only)
      const classNumberOfSessions =
        !isWorkshop && !isEventChoreography && !isStudioBooking ?
          (itemData?.numberOfSessions != null ?
            Number(itemData.numberOfSessions) :
            null) :
          null;
      const defaultTotalSessions = isWorkshop ?
        1 :
        (classNumberOfSessions != null ? classNumberOfSessions : 8);

      // Idempotency check first - check inside transaction to prevent race
      let wasIdempotent = false;
      // Fulfill atomically
      await db.runTransaction(async (tx) => {
        // Re-check idempotency inside transaction
        const existingSnap = await tx.get(globalEnrollRef);
        if (existingSnap.exists) {
          wasIdempotent = true;
          return; // Transaction will return early, no changes committed
        }

        // increment enrolledCount; also optionally decrement spotsLeft
        const startsAt =
          (itemData?.dateTime as admin.firestore.Timestamp | undefined) ||
          (itemData?.startDate as admin.firestore.Timestamp | undefined) ||
          (itemData?.date as admin.firestore.Timestamp | undefined) ||
          null;
        const imageUrl = String(itemData?.imageUrl || "");
        const updates: Record<string, unknown> = {
          enrolledCount: admin.firestore.FieldValue.increment(1),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        };

        // For workshops, also update participant counts
        if (isWorkshop) {
          updates.currentParticipants =
            admin.firestore.FieldValue.increment(1);
          updates.participant_count =
            admin.firestore.FieldValue.increment(1);
        }
        const spotsLeft = Number(itemData?.spotsLeft ?? 0);
        if (Number.isFinite(spotsLeft) && spotsLeft > 0) {
          updates.spotsLeft = admin.firestore.FieldValue.increment(-1);
        }
        tx.set(itemRef, updates, {merge: true});

        tx.set(
          paymentRef,
          {
            orderId,
            userId,
            classId: isWorkshop ? null : itemId,
            workshopId: isWorkshop ? itemId : null,
            itemType,
            amount: amount,
            amount_paise: amount * 100,
            status: "paid",
            razorpay_payment_id: razorpayPaymentId,
            razorpay_order_id: razorpayOrderId,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        // Global mirror keyed by paymentId
        tx.set(
          globalEnrollRef,
          {
            userId,
            user_id: userId, // Support both field names
            itemId,
            itemType,
            amount: amount,
            status: "enrolled",
            paymentId,
            orderId,
            completedSessions: 0, // Initialize session tracking
            // Use class numberOfSessions if available, else default
            totalSessions: defaultTotalSessions,
            remainingSessions: defaultTotalSessions,
            lastSessionAt: null,
            enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
            ts: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );

        // Per-user view
        tx.set(
          userEnrollRef,
          {
            itemId,
            itemType,
            paymentId,
            amount: amount,
            status: "enrolled",
            title: String(title),
            startsAt: startsAt || null,
            imageUrl: imageUrl || "",
            completedSessions: 0, // Initialize session tracking
            // Use class numberOfSessions if available, else default
            totalSessions: defaultTotalSessions,
            remainingSessions: defaultTotalSessions,
            lastSessionAt: null,
            enrolledAt: admin.firestore.FieldValue.serverTimestamp(),
            ts: admin.firestore.FieldValue.serverTimestamp(),
          },
          {merge: true},
        );
        tx.set(
          legacyEnrollRef,
          {
            user_id: userId,
            class_id: isWorkshop ? null : itemId,
            workshop_id: isWorkshop ? itemId : null,
            payment_id: paymentId,
            enrolled_at: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
          },
          {merge: true},
        );

        // Handle event choreography booking update
        if (isEventChoreography) {
          const bookingRef = db.collection("eventChoreoBookings").doc(itemId);
          tx.update(bookingRef, {
            status: "confirmed",
            paymentId: paymentId,
            orderId: orderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpayOrderId: razorpayOrderId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Handle studio booking update
        if (isStudioBooking) {
          const bookingRef = db.collection("studioBookings").doc(itemId);
          tx.update(bookingRef, {
            status: "confirmed",
            paymentId: paymentId,
            orderId: orderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpayOrderId: razorpayOrderId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        // Handle online subscription creation
        if (isOnlineSubscription) {
          const planType = String(data?.planType || "monthly");
          const billingCycle = String(data?.billingCycle || "monthly");
          const subscriptionRef = db.collection("users")
            .doc(userId).collection("subscriptions").doc();
          const startDate = admin.firestore.FieldValue.serverTimestamp();
          const now = new Date();
          const endDate = new Date();

          // Calculate end date based on billing cycle
          if (billingCycle === "monthly") {
            endDate.setMonth(now.getMonth() + 1);
          } else if (billingCycle === "quarterly") {
            endDate.setMonth(now.getMonth() + 3);
          } else {
            endDate.setMonth(now.getMonth() + 1); // Default to monthly
          }

          // Calculate next renewal date (for auto-renewal)
          const nextRenewalDate = new Date(endDate);
          nextRenewalDate.setDate(nextRenewalDate.getDate() - 1);
          // 1 day before expiry

          tx.set(subscriptionRef, {
            planId: itemId,
            planType: planType,
            billingCycle: billingCycle,
            status: "active",
            startDate: startDate,
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            nextRenewalDate: admin.firestore.Timestamp.fromDate(
              nextRenewalDate),
            autoRenew: true,
            paymentId: paymentId,
            orderId: orderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpayOrderId: razorpayOrderId,
            amount: amount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          // Also create a global subscription record for admin tracking
          const globalSubRef = db.collection("subscriptions").doc();
          tx.set(globalSubRef, {
            userId: userId,
            planId: itemId,
            planType: planType,
            billingCycle: billingCycle,
            status: "active",
            startDate: startDate,
            endDate: admin.firestore.Timestamp.fromDate(endDate),
            nextRenewalDate: admin.firestore.Timestamp.fromDate(
              nextRenewalDate),
            autoRenew: true,
            paymentId: paymentId,
            orderId: orderId,
            razorpayPaymentId: razorpayPaymentId,
            razorpayOrderId: razorpayOrderId,
            amount: amount,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      // Check if transaction was idempotent (early return)
      if (wasIdempotent) {
        console.log("FULFILLED (idempotent)", {
          paymentId,
          userId,
          itemId,
          itemType,
        });
        return {ok: true, idempotent: true};
      }

      // Verify enrollment was created
      const verifyGlobalEnroll = await globalEnrollRef.get();
      const verifyUserEnroll = await userEnrollRef.get();

      console.log("FULFILLED", {
        paymentId,
        userId,
        itemId,
        itemType,
        globalEnrollmentDocId: paymentId,
        globalEnrollmentExists: verifyGlobalEnroll.exists,
        userEnrollmentPath: `users/${userId}/enrollments/${itemId}`,
        userEnrollmentExists: verifyUserEnroll.exists,
        userEnrollmentStatus: verifyUserEnroll.data()?.status,
      });

      if (!verifyGlobalEnroll.exists || !verifyUserEnroll.exists) {
        console.error("ERROR: Enrollment documents not created properly", {
          paymentId,
          userId,
          itemId,
        });
      } else {
        // Send enrollment notification
        try {
          const itemName = String(title || itemId);
          const notificationTitle = "✅ Successfully Enrolled!";
          const notificationBody =
            `You're now enrolled in "${itemName}" ${itemType}`;

          // Save to Firestore
          await db.collection("users").doc(userId)
            .collection("notifications").add({
              title: notificationTitle,
              body: notificationBody,
              message: notificationBody,
              type: "enrollment",
              priority: "high",
              read: false,
              isRead: false,
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
              data: {
                itemId: itemId,
                itemName: itemName,
                itemType: itemType,
                paymentId: paymentId,
              },
            });

          // Send FCM push notification
          const userDoc = await db.collection("users").doc(userId).get();
          const userData = userDoc.data();
          const fcmToken = userData?.fcmToken as string | undefined;

          if (fcmToken) {
            try {
              await admin.messaging().send({
                token: fcmToken,
                notification: {
                  title: notificationTitle,
                  body: notificationBody,
                },
                data: {
                  type: "enrollment",
                  priority: "high",
                  itemId: itemId,
                  itemType: itemType,
                },
                android: {
                  priority: "high" as const,
                  notification: {
                    channelId: "enrollments",
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
              console.log(
                `📱 FCM enrollment notification sent to user: ${userId}`,
              );
            } catch (fcmError) {
              console.error(
                "❌ Error sending FCM enrollment notification:",
                fcmError,
              );
            }
          } else {
            console.log(`⚠️ No FCM token found for user: ${userId}`);
          }

          console.log(`📱 Sent enrollment notification to user: ${userId}`);
        } catch (notifError) {
          console.error("❌ Error sending enrollment notification:", notifError);
          // Non-critical, don't fail the payment
        }
      }

      // Email receipts disabled per product decision.

      return {ok: true};
    } catch (err: any) {
      // eslint-disable-next-line no-console
      console.error(
        "confirmRazorpayPayment error",
        err?.message || err,
      );
      if (err instanceof functionsV1.https.HttpsError) throw err;
      throw new functionsV1.https.HttpsError(
        "internal",
        "CONFIRM_FAILED",
        {message: err?.message},
      );
    }
  });


