const admin = require("firebase-admin");
const fs = require("fs");

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function exportCollection(collectionName) {
  const snapshot = await db.collection(collectionName).get();
  const result = [];

  for (const doc of snapshot.docs) {
    result.push({
      id: doc.id,
      data: doc.data()
    });
  }

  return result;
}

async function exportAllFirestore() {
  const collections = [
    "games",
    "scenarios",
    "lockedScenarios",
    "gameSessions",
    "scenario_media_slots",
    "media_assets",
    "sites"
  ];

  const output = {};

  for (const col of collections) {
    console.log(`Exporting ${col}...`);
    output[col] = await exportCollection(col);
  }

  fs.writeFileSync("firestore_export.json", JSON.stringify(output, null, 2));

  console.log("✅ Export terminé : firestore_export.json");
}

exportAllFirestore()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });