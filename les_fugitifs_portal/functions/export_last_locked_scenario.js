const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function exportLastLockedScenario() {
  const outDir = path.join(__dirname, 'firestore_dump');
  fs.mkdirSync(outDir, { recursive: true });

  console.log('📡 Connexion à Firestore...');
  console.log('🔎 Recherche du dernier lockedScenario...');

  const snap = await db
    .collection('lockedScenarios')
    .orderBy('createdAt', 'desc')
    .limit(1)
    .get();

  if (snap.empty) {
    console.log('❌ Aucun document dans lockedScenarios');
    return;
  }

  const doc = snap.docs[0];
  const data = {
    id: doc.id,
    ...doc.data(),
  };

  const filePath = path.join(outDir, 'last_locked_scenario.json');
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');

  console.log('');
  console.log('✅ EXPORT TERMINÉ');
  console.log('📁 Fichier :', filePath);
  console.log('🆔 LockedScenario :', doc.id);
}

exportLastLockedScenario().catch((error) => {
  console.error('');
  console.error('❌ ERREUR :');
  console.error(error);
  process.exit(1);
});