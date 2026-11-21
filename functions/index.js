const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");

initializeApp();
const auth = getAuth();
const db = getFirestore();

function assertAuthenticated(request) {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentication required.");
}

async function assertAdministrator(request) {
  assertAuthenticated(request);
  const caller = await auth.getUser(request.auth.uid);
  const snapshot = await db.collection("users").doc(request.auth.uid).get();
  const profile = snapshot.exists ? snapshot.data() : null;
  const isAdmin =
    (caller.customClaims || {}).role === "administrator" ||
    (profile && profile.role === "administrator");
  if (!isAdmin) {
    throw new HttpsError("permission-denied", "Administrator access required.");
  }
  return caller;
}

async function audit(actor, action, targetUid, details = {}) {
  await db.collection("audit").add({
    actorUid: actor.uid,
    actorEmail: actor.email || null,
    action,
    targetUid,
    details,
    createdAt: FieldValue.serverTimestamp(),
  });
}

function safeEmail(value) {
  if (typeof value !== "string") return null;
  const email = value.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ? email : null;
}

function generateTemporaryPassword() {
  const alphabet =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  const bytes = crypto.randomBytes(24);
  let password = "";
  for (const byte of bytes) password += alphabet[byte % alphabet.length];
  return password;
}

exports.createMember = onCall(async (request) => {
  const actor = await assertAdministrator(request);
  const name = typeof request.data.name === "string"
    ? request.data.name.trim()
    : "";
  const email = safeEmail(request.data.email);
  const role = request.data.role === "administrator" ? "administrator" : "member";
  if (name.length < 2 || name.length > 100) {
    throw new HttpsError("invalid-argument", "Enter a valid member name.");
  }
  if (!email) throw new HttpsError("invalid-argument", "Enter a valid email.");
  const temporaryPassword = generateTemporaryPassword();
  let user;
  try {
    user = await auth.createUser({
      email,
      password: temporaryPassword,
      displayName: name,
      disabled: false,
    });
  } catch (error) {
    if (error.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "An account already exists for this email.");
    }
    throw new HttpsError("internal", "Could not create the account.");
  }
  await auth.setCustomUserClaims(user.uid, { role });
  await db.collection("users").doc(user.uid).set({
    uid: user.uid,
    name,
    email,
    role,
    accountStatus: "active",
    approvalStatus: "approved",
    mustChangePassword: true,
    locked: false,
    failedAttempts: 0,
    registeredAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  await audit(actor, "create_member", user.uid, { role, email });
  return { uid: user.uid, email, temporaryPassword };
});

exports.updateMember = onCall(async (request) => {
  const actor = await assertAdministrator(request);
  const uid = request.data.uid;
  if (typeof uid !== "string" || !uid) {
    throw new HttpsError("invalid-argument", "A valid member is required.");
  }
  const target = await auth.getUser(uid);
  if (process.env.PRIMARY_ADMIN_EMAIL &&
      target.email?.toLowerCase() === process.env.PRIMARY_ADMIN_EMAIL.toLowerCase() &&
      request.data.role && request.data.role !== "administrator") {
    throw new HttpsError("failed-precondition", "The primary administrator cannot be demoted.");
  }
  const updates = { updatedAt: FieldValue.serverTimestamp() };
  if (typeof request.data.name === "string") {
    const name = request.data.name.trim();
    if (name.length < 2 || name.length > 100) {
      throw new HttpsError("invalid-argument", "Enter a valid member name.");
    }
    updates.name = name;
  }
  if (typeof request.data.role === "string") {
    if (!["administrator", "member"].includes(request.data.role)) {
      throw new HttpsError("invalid-argument", "Invalid role.");
    }
    updates.role = request.data.role;
    await auth.setCustomUserClaims(uid, { role: request.data.role });
  }
  if (["active", "pending", "suspended", "rejected"].includes(request.data.accountStatus)) {
    updates.accountStatus = request.data.accountStatus;
  }
  if (["pending", "approved", "rejected"].includes(request.data.approvalStatus)) {
    updates.approvalStatus = request.data.approvalStatus;
  }
  await db.collection("users").doc(uid).set(updates, { merge: true });
  await audit(actor, "update_member", uid, updates);
  return { success: true };
});

exports.resetMemberLockout = onCall(async (request) => {
  const actor = await assertAdministrator(request);
  const uid = request.data.uid;
  if (typeof uid !== "string" || !uid) {
    throw new HttpsError("invalid-argument", "A valid member is required.");
  }
  await db.collection("users").doc(uid).set({
    locked: false,
    lockoutReason: null,
    lockoutAt: null,
    failedAttempts: 0,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await auth.updateUser(uid, { disabled: false });
  await audit(actor, "reset_lockout", uid, {});
  return { success: true };
});

exports.resetMemberPassword = onCall(async (request) => {
  const actor = await assertAdministrator(request);
  const uid = request.data.uid;
  if (typeof uid !== "string" || !uid) {
    throw new HttpsError("invalid-argument", "A valid member is required.");
  }
  const user = await auth.getUser(uid);
  if (!user.email) throw new HttpsError("failed-precondition", "This account has no email.");
  await db.collection("users").doc(uid).set({
    mustChangePassword: true,
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await auth.generatePasswordResetLink(user.email);
  await audit(actor, "password_reset_requested", uid, {});
  return { success: true };
});

exports.deleteMember = onCall(async (request) => {
  const actor = await assertAdministrator(request);
  const uid = request.data.uid;
  if (typeof uid !== "string" || !uid) {
    throw new HttpsError("invalid-argument", "A valid member is required.");
  }
  const target = await auth.getUser(uid);
  if (process.env.PRIMARY_ADMIN_EMAIL &&
      target.email?.toLowerCase() === process.env.PRIMARY_ADMIN_EMAIL.toLowerCase()) {
    throw new HttpsError("failed-precondition", "The primary administrator cannot be deleted.");
  }
  await auth.deleteUser(uid);
  await db.collection("users").doc(uid).delete();
  await audit(actor, "delete_member", uid, {});
  return { success: true };
});

exports.completeFirstLoginPasswordChange = onCall(async (request) => {
  assertAuthenticated(request);
  await db.collection("users").doc(request.auth.uid).set({
    mustChangePassword: false,
    passwordChangedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return { success: true };
});
