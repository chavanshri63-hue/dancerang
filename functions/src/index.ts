/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

/* eslint-disable max-len, indent, @typescript-eslint/no-explicit-any */
import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
export {
  verifyRazorpaySignature,
  finalizePayment,
} from "./razorpay";
export {createRazorpayOrder, confirmRazorpayPayment} from "./payments";
export {checkExpiredSubscriptionsManual} from "./subscription-expiry";
export {cleanNotificationData} from "./clean-notifications";
export {sendAdminNotification} from "./send-notifications";
// New: admin migration callable

// Initialize admin SDK once
try {
  admin.app();
} catch (_) {
  admin.initializeApp();
}

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
// Ensure v2 callables deploy in asia-south1 to match client config
setGlobalOptions({maxInstances: 10, region: "asia-south1"});

/**
 * Securely set role for a user after verifying a shared key.
 * Expected data: { role: 'Student' | 'Faculty' | 'Admin', key?: string }
 * Auth required.
 */
export const setUserRole = onCall<{role: string, key?: string}>(
  {cors: true},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "User must be authenticated");
    }

    const role = (request.data?.role || "Student").trim();
    const key = (request.data?.key || "").trim();

    // Normalize key (remove any extra whitespace)
    const normalizedKey = key.trim();

    const validRoles = new Set(["Student", "Faculty", "Admin"]);
    if (!validRoles.has(role)) {
      throw new HttpsError("invalid-argument", "Invalid role");
    }

    // Load keys from Firestore: appSettings/roleKeys
    // Fallback to env if doc missing
    const db = admin.firestore();
    let adminKey = process.env.ADMIN_KEY || "";
    let facultyKey = process.env.FACULTY_KEY || "";
    try {
      const doc = await db.collection("appSettings").doc("roleKeys").get();
      if (doc.exists) {
        const data = doc.data() as any;
        adminKey = data?.adminKey || adminKey;
        facultyKey = data?.facultyKey || facultyKey;
      }
    } catch (e) {
      console.error("Error loading role keys from Firestore:", e);
      // ignore read error; will fall back to env
    }

    // Default fallback keys if none configured (for initial setup)
    if (!adminKey) adminKey = "ANUSHREE0918";
    if (!facultyKey) facultyKey = "DANCERANG5678";

    // Verify keys only for privileged roles (normalize both for comparison)
    const normalizedAdminKey = (adminKey || "").trim();
    const normalizedFacultyKey = (facultyKey || "").trim();

    if (role === "Admin" && normalizedKey !== normalizedAdminKey) {
      throw new HttpsError("permission-denied", "Invalid admin key");
    }
    if (role === "Faculty" && normalizedKey !== normalizedFacultyKey) {
      throw new HttpsError("permission-denied", "Invalid faculty key");
    }

    // Set custom claims for admin/faculty; clear for student
    const claims: Record<string, unknown> = {};
    if (role === "Admin") claims.admin = true;
    if (role === "Faculty") claims.faculty = true;

    try {
      await admin.auth().setCustomUserClaims(uid, claims);
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Failed to set claims: ${msg}`);
    }

    // Persist role in Firestore users/{uid}
    try {
      await db.collection("users").doc(uid).set({
        role,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Failed to write user role: ${msg}`);
    }

    return {ok: true, role};
  },
);

// Admin-only: set Razorpay public keyId in appSettings/razorpay
export const setRazorpayKeyId = onCall<{keyId: string}>(
  {cors: true},
  async (request) => {
    const uid = request.auth?.uid;
    const isAdmin = request.auth?.token?.admin === true;
    if (!uid || !isAdmin) {
      throw new HttpsError("permission-denied", "Admin only");
    }

    const keyId = String(request.data?.keyId || "").trim();
    if (!keyId) {
      throw new HttpsError("invalid-argument", "keyId required");
    }

    try {
      await admin
        .firestore()
        .collection("appSettings")
        .doc("razorpay")
        .set({keyId, updatedAt: admin.firestore.FieldValue.serverTimestamp()}, {merge: true});
      return {ok: true};
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      throw new HttpsError("internal", `Failed to set keyId: ${msg}`);
    }
  },
);

/**
 * Admin-only: migrate legacy enrolments → canonical enrollments.
 * - Copies global `enrolments/*` to `enrollments/*` if missing
 * - Copies user `users/{uid}/enrolments/*` to `users/{uid}/enrollments/*` if missing
 */
export const migrateEnrolmentsToEnrollments = onCall<{
  dryRun?: boolean;
}>({cors: true}, async (request) => {
  const isAdmin = request.auth?.token?.admin === true;
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Admin only");
  }

  const dryRun = Boolean(request.data?.dryRun);
  const db = admin.firestore();
  let migratedGlobal = 0;
  let migratedUser = 0;

  // Global collection migration
  const legacySnaps = await db.collection("enrolments").get();
  for (const doc of legacySnaps.docs) {
    const target = db.collection("enrollments").doc(doc.id);
    const targetSnap = await target.get();
    if (!targetSnap.exists) {
      migratedGlobal++;
      if (!dryRun) {
        await target.set(doc.data(), {merge: true});
      }
    }
  }

  // Per-user subcollections
  const users = await db.collection("users").select().get();
  for (const u of users.docs) {
    const userId = u.id;
    const legacyCol = db.collection("users").doc(userId).collection("enrolments");
    const legacyUserSnaps = await legacyCol.get();
    if (legacyUserSnaps.empty) continue;
    for (const d of legacyUserSnaps.docs) {
      const target = db.collection("users").doc(userId).collection("enrollments").doc(d.id);
      const targetSnap = await target.get();
      if (!targetSnap.exists) {
        migratedUser++;
        if (!dryRun) {
          await target.set(d.data(), {merge: true});
        }
      }
    }
  }

  return {ok: true, migratedGlobal, migratedUser, dryRun};
});
