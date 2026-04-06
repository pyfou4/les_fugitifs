const admin = require("firebase-admin");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");

admin.initializeApp();

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

const firestore = admin.firestore();
const auth = admin.auth();

async function requireActiveAdmin(authData) {
  if (!authData?.uid) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }

  const profileSnap = await firestore.collection("portalUsers").doc(authData.uid).get();
  if (!profileSnap.exists) {
    throw new HttpsError(
      "permission-denied",
      "Aucun profil portail trouvé pour cet utilisateur."
    );
  }

  const profile = profileSnap.data() || {};
  if (profile.isActive !== true) {
    throw new HttpsError(
      "permission-denied",
      "Le compte portail est désactivé."
    );
  }

  if ((profile.role || "").toString().trim().toLowerCase() !== "admin") {
    throw new HttpsError(
      "permission-denied",
      "Seul un admin peut créer un employé portail."
    );
  }

  return {
    uid: authData.uid,
    displayName: (profile.displayName || "").toString(),
    email: (profile.email || "").toString(),
  };
}

function normalizeRole(rawRole) {
  const value = (rawRole || "").toString().trim().toLowerCase();
  switch (value) {
    case "admin":
    case "scenariste":
    case "caissier":
    case "maitre_jeu":
      return value;
    default:
      throw new HttpsError("invalid-argument", "Rôle invalide.");
  }
}

exports.createPortalEmployee = onCall(async (request) => {
  const currentAdmin = await requireActiveAdmin(request.auth);

  const data = request.data || {};
  const email = (data.email || "").toString().trim().toLowerCase();
  const displayName = (data.displayName || "").toString().trim();
  const password = (data.password || "").toString();
  const role = normalizeRole(data.role);
  const isActive = data.isActive !== false;

  if (!email || !displayName || !password) {
    throw new HttpsError(
      "invalid-argument",
      "Email, nom affiché et mot de passe sont obligatoires."
    );
  }

  if (password.length < 6) {
    throw new HttpsError(
      "invalid-argument",
      "Le mot de passe doit contenir au moins 6 caractères."
    );
  }

  try {
    const userRecord = await auth.createUser({
      email,
      password,
      displayName,
      disabled: !isActive,
    });

    const now = new Date().toISOString();

    await firestore.collection("portalUsers").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      displayName,
      role,
      isActive,
      createdAt: now,
      createdBy: currentAdmin.uid,
      updatedAt: now,
      updatedBy: currentAdmin.uid,
    });

    return {
      success: true,
      uid: userRecord.uid,
      email,
      displayName,
      role,
      isActive,
    };
  } catch (error) {
    const code = error?.code || "";

    if (code === "auth/email-already-exists") {
      throw new HttpsError(
        "already-exists",
        "Un compte Firebase Auth existe déjà avec cet email."
      );
    }

    if (code === "auth/invalid-password") {
      throw new HttpsError(
        "invalid-argument",
        "Mot de passe refusé par Firebase Auth."
      );
    }

    console.error("createPortalEmployee failed", error);
    throw new HttpsError(
      "internal",
      "Impossible de créer le nouvel employé."
    );
  }
});