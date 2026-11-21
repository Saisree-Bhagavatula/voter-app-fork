const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

initializeApp({ credential: applicationDefault(), projectId: "voters-cdm" });

async function setPrimaryAdmin(email) {
  if (!email) throw new Error("Usage: node set_primary_admin.js admin@example.com");
  const normalized = email.trim().toLowerCase();
  const auth = getAuth();
  const db = getFirestore();
  const user = await auth.getUserByEmail(normalized);
  await auth.setCustomUserClaims(user.uid, { role: "administrator" });
  await db.collection("users").doc(user.uid).set({
    uid: user.uid,
    name: user.displayName || "Primary Administrator",
    email: normalized,
    role: "administrator",
    accountStatus: "active",
    approvalStatus: "approved",
    mustChangePassword: false,
    locked: false,
    failedAttempts: 0,
    registeredAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`Primary administrator claim set for ${normalized}`);
}

setPrimaryAdmin(process.argv[2]).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
