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

  fs.writeFileSync("export.json", JSON.stringify(result, null, 2), "utf8");

  console.log("✅ Export terminé → export.json");
}

main().catch((error) => {
  console.error("❌ Erreur pendant l'export :", error);
  process.exit(1);
});