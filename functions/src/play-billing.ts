/* eslint-disable max-len, indent, @typescript-eslint/no-explicit-any */
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {google} from "googleapis";
import * as crypto from "crypto";

let cachedPackageName: string | null = null;
const FALLBACK_PACKAGE_NAME = "com.dancerang.dancerang";

/**
 * Resolve the Play Store package name for the app.
 * @return {Promise<string>} The package name.
 */
async function resolvePackageName(): Promise<string> {
  if (cachedPackageName) return cachedPackageName;
  const envName = (process.env.PLAY_PACKAGE_NAME || "").trim();
  if (envName) {
    cachedPackageName = envName;
    return envName;
  }

  try {
    const doc = await admin.firestore().collection("appSettings").doc("play").get();
    const data = doc.data() as any;
    const fromDb = String(data?.packageName || "").trim();
    if (fromDb) {
      cachedPackageName = fromDb;
      return fromDb;
    }
  } catch (e) {
    console.error("Error loading Play package name:", e);
  }

  // Fallback to a known app id to avoid blocking activation in production/test.
  // If you have multiple Android apps, configure PLAY_PACKAGE_NAME or appSettings/play.packageName instead.
  console.warn("Play package name not configured; using fallback:", FALLBACK_PACKAGE_NAME);
  cachedPackageName = FALLBACK_PACKAGE_NAME;
  return FALLBACK_PACKAGE_NAME;
}

/**
 * Verify a Play Store subscription purchase and activate access.
 */
export const verifyPlaySubscription = onCall({cors: true, region: "asia-south1"}, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "User must be authenticated");
  }

  const productId = String(request.data?.productId || "").trim();
  const purchaseToken = String(request.data?.purchaseToken || "").trim();
  const planId = String(request.data?.planId || "monthly").trim();
  const planName = String(request.data?.planName || "Monthly Plan").trim();
  const planType = String(request.data?.planType || "monthly").trim();
  const billingCycle = String(request.data?.billingCycle || "monthly").trim();
  const amount = Number(request.data?.amount || 0);
  const store = String(request.data?.store || "play_store").trim() || "play_store";

  if (!productId || !purchaseToken) {
    throw new HttpsError("invalid-argument", "Missing productId or purchaseToken");
  }

  try {
    const packageName = await resolvePackageName();
    const tokenHash = crypto.createHash("sha256").update(purchaseToken).digest("hex");
    console.log("verifyPlaySubscription request", {
      uid,
      productId,
      packageName,
      tokenHash,
      planId,
      billingCycle,
      store,
    });

    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const publisher = google.androidpublisher({version: "v3", auth});

    const purchase = await publisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const data = purchase.data as any;
    const expiryMillis = Number(data?.expiryTimeMillis || 0);
    if (!expiryMillis) {
      throw new HttpsError("failed-precondition", "Invalid subscription response");
    }

    const now = Date.now();
    if (expiryMillis <= now) {
      return {ok: false, message: "Subscription expired"};
    }

    const startMillis = Number(data?.startTimeMillis || now);
    const endDate = admin.firestore.Timestamp.fromMillis(expiryMillis);
    const startDate = admin.firestore.Timestamp.fromMillis(startMillis);
    const nextRenewalDate = admin.firestore.Timestamp.fromMillis(
      Math.max(expiryMillis - 24 * 60 * 60 * 1000, startMillis),
    );
    const autoRenewing = data?.autoRenewing === true;
    const paymentState = data?.paymentState ?? null;
    const cancelReason = data?.cancelReason ?? null;
    const orderId = data?.orderId ?? null;
    const linkedPurchaseToken = data?.linkedPurchaseToken ?? null;

    const subscriptionId = `iap_${tokenHash}`;

    const db = admin.firestore();
    const userSubs = db.collection("users").doc(uid).collection("subscriptions");
    const globalSubs = db.collection("subscriptions");
    const userSubRef = userSubs.doc(subscriptionId);
    const globalSubRef = globalSubs.doc(subscriptionId);

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(userSubRef);
      if (existing.exists) {
        return;
      }

      const activeSubs = await tx.get(
        userSubs.where("status", "==", "active"),
      );
      for (const doc of activeSubs.docs) {
        tx.update(doc.ref, {
          status: "expired",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      tx.set(userSubRef, {
        planId,
        planName,
        planType,
        billingCycle,
        status: "active",
        startDate,
        endDate,
        nextRenewalDate,
        autoRenew: autoRenewing,
        amount,
        productId,
        purchaseToken,
        orderId,
        linkedPurchaseToken,
        paymentState,
        cancelReason,
        store,
        paymentProvider: store,
        source: "iap",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.set(globalSubRef, {
        userId: uid,
        userSubscriptionId: userSubRef.id,
        planId,
        planName,
        planType,
        billingCycle,
        status: "active",
        startDate,
        endDate,
        nextRenewalDate,
        autoRenew: autoRenewing,
        amount,
        productId,
        purchaseToken,
        orderId,
        linkedPurchaseToken,
        paymentState,
        cancelReason,
        store,
        paymentProvider: store,
        source: "iap",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {ok: true, subscriptionId};
  } catch (e: any) {
    const message =
      e?.response?.data?.error?.message ||
      e?.message ||
      String(e);
    const status = e?.response?.status || e?.code || null;
    console.error("Play subscription verify error:", {status, message});
    throw new HttpsError("internal", message);
  }
});
