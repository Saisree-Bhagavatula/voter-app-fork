const fs = require("fs");
const path = require("path");

const projectId = "voters-cdm";
const email = process.argv[2];

if (!email) {
  throw new Error("Usage: node bootstrap_primary_admin.js admin@example.com");
}

const normalizedEmail = email.trim().toLowerCase();
const configPath = path.join(
  process.env.USERPROFILE,
  ".config",
  "configstore",
  "firebase-tools.json",
);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const refreshToken = config.tokens && config.tokens.refresh_token;

if (!refreshToken) {
  throw new Error("Firebase CLI refresh credentials are unavailable.");
}

async function refreshAccessToken() {
  const body = new URLSearchParams({
    refresh_token: refreshToken,
    client_id:
      "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: "j9iVZfS8kkCEFUPaAeJV0sAi",
    grant_type: "refresh_token",
  });
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body,
  });
  const data = await response.json();
  if (!response.ok || !data.access_token) {
    throw new Error(data.error_description || data.error || "OAuth refresh failed.");
  }
  return data.access_token;
}

async function jsonRequest(url, accessToken, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error && data.error.message
      ? data.error.message
      : "Firebase request failed.");
  }
  return data;
}

async function main() {
  const accessToken = await refreshAccessToken();
  const authHeaders = {
    authorization: `Bearer ${accessToken}`,
    "content-type": "application/json",
  };
  const lookup = await jsonRequest(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:lookup`,
    accessToken,
    { email: [normalizedEmail] },
  );
  const account = (lookup.users || []).find(
    (user) => (user.email || "").toLowerCase() === normalizedEmail,
  );
  if (!account) {
    throw new Error("The existing administrator account was not found.");
  }

  await jsonRequest(
    `https://identitytoolkit.googleapis.com/v1/projects/${projectId}/accounts:update`,
    accessToken,
    {
      localId: account.localId,
      customAttributes: JSON.stringify({ role: "administrator" }),
      disabled: false,
    },
  );

  const fields = {
    uid: { stringValue: account.localId },
    name: { stringValue: "Primary Administrator" },
    email: { stringValue: normalizedEmail },
    role: { stringValue: "administrator" },
    accountStatus: { stringValue: "active" },
    approvalStatus: { stringValue: "approved" },
    mustChangePassword: { booleanValue: false },
    locked: { booleanValue: false },
    failedAttempts: { integerValue: "0" },
    primaryAdmin: { booleanValue: true },
  };
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${account.localId}`,
    {
      method: "PATCH",
      headers: authHeaders,
      body: JSON.stringify({ fields }),
    },
  );
  const result = await response.json();
  if (!response.ok) {
    throw new Error(result.error && result.error.message
      ? result.error.message
      : "Could not create the administrator profile.");
  }
  console.log(`ADMIN_BOOTSTRAP_COMPLETE:${account.localId}`);
}

main().catch((error) => {
  console.error(`ADMIN_BOOTSTRAP_FAILED:${error.message}`);
  process.exit(1);
});
