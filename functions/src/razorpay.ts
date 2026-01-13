/* eslint-disable max-len, indent, @typescript-eslint/no-explicit-any, require-jsdoc */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import Razorpay from "razorpay";
import * as crypto from "crypto";

/**
 * Create Razorpay client from environment config.
 * @return {Razorpay} Initialized Razorpay client
 */
/**
 * Secret bindings for Razorpay credentials.
 * These are provided via Firebase Functions Secrets and attached to
 * onCall handlers through the `secrets` option to ensure runtime access.
 */
const RZP_KEY_ID = defineSecret("RAZORPAY_KEY_ID");
const RZP_KEY_SECRET = defineSecret("RAZORPAY_KEY_SECRET");

function getClient() {
  const cfg = (functions.config()?.razorpay || {}) as any;
  const keyId =
    process.env.RAZORPAY_KEY_ID ||
    process.env.razorpay_key_id ||
    process.env.razorpay_keyId ||
    cfg.key_id ||
    "";

  const keySecret =
    process.env.RAZORPAY_KEY_SECRET ||
    process.env.razorpay_key_secret ||
    process.env.razorpay_keySecret ||
    cfg.key_secret ||
    "";

  if (!keyId || !keySecret) {
    throw new HttpsError(
      "failed-precondition",
      "Razorpay keys not configured",
    );
  }
  return new Razorpay({key_id: keyId, key_secret: keySecret});
}

type CreateOrderData = {
  amount: number;
  receipt?: string;
  notes?: Record<string, unknown>;
};

/**
 * Create a Razorpay order (amount in paise, currency INR).
 */
export const createRazorpayOrder = onCall<CreateOrderData>(
  {cors: true, secrets: [RZP_KEY_ID, RZP_KEY_SECRET]},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const amount = req.data?.amount;
    const receipt = req.data?.receipt || `rcpt_${Date.now()}`;
    const notes = (req.data?.notes || {}) as Record<string, string | number>;

    if (!Number.isInteger(amount) || amount <= 0) {
      throw new HttpsError(
        "invalid-argument",
        "Amount must be positive integer in paise",
      );
    }

    const rz = getClient();
    const order: any = await rz.orders.create({
      amount,
      currency: "INR",
      receipt,
      notes,
    } as any);

    // Optional: persist a mapping for audit
    try {
      await admin
        .firestore()
        .collection("razorpay_orders")
        .doc(String(order.id))
        .set({
          uid,
          amount,
          currency: String(order.currency),
          receipt,
          notes,
          status: String(order.status),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
      // Ignore audit write failures; payment flow can continue.
      // eslint-disable-next-line no-console
      console.warn("razorpay_orders audit write failed", e);
    }

    return {order};
  },
);

type VerifyData = {
  orderId: string;
  paymentId: string;
  signature: string;
};

/**
 * Verify Razorpay signature received after successful payment.
 */
export const verifyRazorpaySignature = onCall<VerifyData>(
  {cors: true, secrets: [RZP_KEY_SECRET]},
  async (req) => {
    const uid = req.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const {orderId, paymentId, signature} = req.data || ({} as VerifyData);
    if (!orderId || !paymentId || !signature) {
      throw new HttpsError(
        "invalid-argument",
        "Missing orderId/paymentId/signature",
      );
    }

    const cfg = (functions.config()?.razorpay || {}) as any;
    const keySecret =
      process.env.RAZORPAY_KEY_SECRET ||
      process.env.razorpay_key_secret ||
      process.env.razorpay_keySecret ||
      cfg.key_secret ||
      "";
    if (!keySecret) {
      throw new HttpsError(
        "failed-precondition",
        "Razorpay secret not configured",
      );
    }

    const payload = `${orderId}|${paymentId}`;
    const expected = crypto
      .createHmac("sha256", keySecret)
      .update(payload)
      .digest("hex");
    const valid = expected === signature;
    return {valid};
  },
);

type FinalizeData = {
  paymentId: string;
  razorpayPaymentId?: string; // platform payment id for transfer
  razorpayOrderId?: string;
};

/**
 * Finalize payment: mark success and enroll user atomically on server.
 */
export const finalizePayment = onCall<FinalizeData>(
  {cors: true, secrets: [RZP_KEY_ID, RZP_KEY_SECRET]},
  async (req) => {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "User must be authenticated");

  const paymentId = req.data?.paymentId;
  if (!paymentId) throw new HttpsError("invalid-argument", "paymentId required");
  const razorpayPaymentId = String(req.data?.razorpayPaymentId || "");
  const razorpayOrderId = String(req.data?.razorpayOrderId || "");

  const db = admin.firestore();
  const paymentRef = db.collection("payments").doc(paymentId);
  const paymentSnap = await paymentRef.get();
  if (!paymentSnap.exists) throw new HttpsError("not-found", "Payment not found");
  const data = paymentSnap.data() as any;
  if (data.user_id !== uid) throw new HttpsError("permission-denied", "Not owner");

  const paymentType = String(data.payment_type || "");
  const itemId = String(data.item_id || "");
  const amount = Number(data.amount || 0);

  let itemName = "";

  await db.runTransaction(async (tx) => {
    tx.update(paymentRef, {
      status: "success",
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      transaction_id: data.transaction_id || `TXN_${Date.now()}`,
      razorpay_payment_id: razorpayPaymentId || data.razorpay_payment_id || null,
      razorpay_order_id: razorpayOrderId || data.razorpay_order_id || null,
    });

    if (paymentType === "class_fee") {
      const enrollCol = db.collection("class_enrollments");
      tx.set(enrollCol.doc(), {
        user_id: uid,
        class_id: itemId,
        payment_id: paymentId,
        enrolled_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
      });
      const classDoc = db.collection("classes").doc(itemId);
      tx.update(classDoc, {
        participant_count: admin.firestore.FieldValue.increment(1),
        currentBookings: admin.firestore.FieldValue.increment(1),
        enrolledCount: admin.firestore.FieldValue.increment(1),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (paymentType === "workshop") {
      const enrollCol = db.collection("workshop_enrollments");
      tx.set(enrollCol.doc(), {
        user_id: uid,
        workshop_id: itemId,
        payment_id: paymentId,
        enrolled_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
      });
      tx.update(db.collection("workshops").doc(itemId), {
        participant_count: admin.firestore.FieldValue.increment(1),
        currentParticipants: admin.firestore.FieldValue.increment(1),
        enrolledCount: admin.firestore.FieldValue.increment(1),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (paymentType === "event") {
      const enrollCol = db.collection("event_enrollments");
      tx.set(enrollCol.doc(), {
        user_id: uid,
        event_id: itemId,
        payment_id: paymentId,
        enrolled_at: admin.firestore.FieldValue.serverTimestamp(),
        status: "active",
      });
    }
  });

  // Get item name for logging
  try {
    if (paymentType === "class_fee") {
      const classDoc = await db.collection("classes").doc(itemId).get();
      if (classDoc.exists) {
        const classData = classDoc.data() as any;
        itemName = classData.name || "Class";
      }
    } else if (paymentType === "workshop") {
      const workshopDoc = await db.collection("workshops").doc(itemId).get();
      if (workshopDoc.exists) {
        const workshopData = workshopDoc.data() as any;
        itemName = workshopData.title || "Workshop";
      }
    }
    console.log(`✅ Payment finalized for enrollment: ${itemName}`);
  } catch (e) {
    console.error("❌ Error getting item name:", e);
  }

  // Attempt automatic payout/transfer to admin account (if configured)
  try {
    // Allow env or functions config for admin account id
    const cfg = (functions.config()?.razorpay || {}) as any;
    const adminAccount =
      process.env.RAZORPAY_ADMIN_ACCOUNT_ID ||
      process.env.razorpay_admin_account_id ||
      cfg.admin_account_id ||
      "";
    if (adminAccount && razorpayPaymentId && amount > 0) {
      const rz = getClient();
      // Create a transfer from captured payment to the admin account
      const transferPayload: any = {
        transfers: [
          {
            account: adminAccount,
            amount: amount, // in paise
            currency: "INR",
            notes: {paymentId, paymentType, itemId},
          },
        ],
      };
      const transferResp = await (rz as any).payments.transfer(razorpayPaymentId, transferPayload);
      await paymentRef.update({
        payout_status: "transferred",
        payout: {
          admin_account: adminAccount,
          transfer_response: transferResp,
          transferred_at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
    } else {
      await paymentRef.update({payout_status: adminAccount ? "awaiting_payment_id" : "not_configured"});
    }
  } catch (e) {
    // eslint-disable-next-line no-console
    console.error("Payout transfer failed", e);
    await paymentRef.update({payout_status: "failed", payout_error: String(e)});
  }

  // Generate a simple embedded receipt in the payment document
  try {
    const receipt = {
      id: paymentId,
      user_id: uid,
      amount,
      currency: "INR",
      description: String(data.description || ""),
      payment_type: paymentType,
      item_id: itemId,
      razorpay_payment_id: razorpayPaymentId || null,
      razorpay_order_id: razorpayOrderId || null,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    };
    await paymentRef.update({receipt});
  } catch (e) {
    // eslint-disable-next-line no-console
    console.warn("Failed to write receipt to payment doc", e);
  }

  return {ok: true};
});


