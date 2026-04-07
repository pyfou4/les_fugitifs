const admin = require("firebase-admin");
const fs = require("fs");

// 🔑 Le fichier de clé privée doit être dans le même dossier
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function exportCollection(path) {
  const snapshot = await db.collection(path).get();
  const data = {};

  snapshot.forEach((doc) => {
    data[doc.id] = doc.data();
  });

  return data;
}

async function exportDocument(path) {
  const snapshot = await db.doc(path).get();

  if (!snapshot.exists) {
    return null;
  }

  return snapshot.data();
}

async function main() {
  const result = {};

  // Jeu maître
  result.game = await exportDocument("games/les_fugitifs");
  result.placeTemplates = await exportCollection("games/les_fugitifs/placeTemplates");
  result.suspects = await exportCollection("games/les_fugitifs/suspects");
  result.motives = await exportCollection("games/les_fugitifs/motives");

  // Site Sion
  result.site = await exportDocument("sites/sion");
  result.sitePlaces = await exportCollection("sites/sion/places");
try {
  result.sessions = await exportCollection("sessions");
} catch (e) {
  result.sessions = { _error: "collection sessions introuvable" };
}

try {
  result.gameSessions = await exportCollection("gameSessions");
} catch (e) {
  result.gameSessions = { _error: "collection gameSessions introuvable" };
}

try {
  result.runtimeSessions = await exportCollection("runtimeSessions");
} catch (e) {
  result.runtimeSessions = { _error: "collection runtimeSessions introuvable" };
}

try {
  result.portalUsers = await exportCollection("portalUsers");
} catch (e) {
  result.portalUsers = { _error: "collection portalUsers introuvable" };
}

  fs.writeFileSync("export.json", JSON.stringify(result, null, 2), "utf8");

  console.log("✅ Export terminé → export.json");
}

main().catch((error) => {
  console.error("❌ Erreur pendant l'export :", error);
  process.exit(1);
});