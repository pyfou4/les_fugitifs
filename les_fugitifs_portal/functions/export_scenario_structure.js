const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// ✅ déjà bon
const scenarioId = 'les_fugitifs';

// ✅ utilise ta clé EXISTANTE
const serviceAccount = require('./serviceAccountKey.json');

// 🔥 initialisation CORRECTE (clé + projectId automatique)
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

async function exportScenarioStructure() {
  const outDir = path.join(__dirname, 'firestore_dump');
  fs.mkdirSync(outDir, { recursive: true });

  console.log('📡 Connexion à Firestore...');
  console.log('📁 Scenario ID :', scenarioId);

  const scenarioRef = db.collection('scenarios').doc(scenarioId);

  const [
    scenarioSnap,
    suspectsSnap,
    motivesSnap,
    placeTemplatesSnap,
    clueSystemSnap,
  ] = await Promise.all([
    scenarioRef.get(),
    scenarioRef.collection('suspects').get(),
    scenarioRef.collection('motives').get(),
    scenarioRef.collection('placeTemplates').get(),
    scenarioRef.collection('clueSystem').doc('main').get(),
  ]);

  console.log('📥 Données récupérées');

  const scenarioMeta = scenarioSnap.exists
    ? { id: scenarioSnap.id, ...scenarioSnap.data() }
    : null;

  const suspects = suspectsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const motives = motivesSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const placeTemplates = placeTemplatesSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const clueSystem = clueSystemSnap.exists
    ? { id: clueSystemSnap.id, ...clueSystemSnap.data() }
    : null;

  fs.writeFileSync(
    path.join(outDir, 'scenario_meta.json'),
    JSON.stringify(scenarioMeta, null, 2)
  );

  fs.writeFileSync(
    path.join(outDir, 'suspects.json'),
    JSON.stringify(suspects, null, 2)
  );

  fs.writeFileSync(
    path.join(outDir, 'motives.json'),
    JSON.stringify(motives, null, 2)
  );

  fs.writeFileSync(
    path.join(outDir, 'placeTemplates.json'),
    JSON.stringify(placeTemplates, null, 2)
  );

  fs.writeFileSync(
    path.join(outDir, 'clueSystem.json'),
    JSON.stringify(clueSystem, null, 2)
  );

  console.log('');
  console.log('✅ EXPORT TERMINÉ');
  console.log('📁 Dossier :', outDir);
}

exportScenarioStructure().catch((error) => {
  console.error('');
  console.error('❌ ERREUR :');
  console.error(error);
  process.exit(1);
});