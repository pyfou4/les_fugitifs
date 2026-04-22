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

async function backupRuntimeState() {
  const outDir = path.join(
    __dirname,
    'firestore_backup_' + new Date().toISOString().replace(/[:.]/g, '-')
  );
  fs.mkdirSync(outDir, { recursive: true });

  const scenarioId = 'les_fugitifs';
  const scenarioRef = db.collection('scenarios').doc(scenarioId);

  console.log('📡 Connexion à Firestore...');
  console.log('💾 Sauvegarde de scenarios/' + scenarioId);

  const [
    scenarioSnap,
    suspectsSnap,
    motivesSnap,
    placeTemplatesSnap,
    clueSystemSnap,
    lockedSnap,
  ] = await Promise.all([
    scenarioRef.get(),
    scenarioRef.collection('suspects').get(),
    scenarioRef.collection('motives').get(),
    scenarioRef.collection('placeTemplates').get(),
    scenarioRef.collection('clueSystem').get(),
    db.collection('lockedScenarios').orderBy('createdAt', 'desc').limit(1).get(),
  ]);

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

  const clueSystem = clueSystemSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const lastLockedScenario = lockedSnap.empty
    ? null
    : {
        id: lockedSnap.docs[0].id,
        ...lockedSnap.docs[0].data(),
      };

  fs.writeFileSync(
    path.join(outDir, 'scenario_meta.json'),
    JSON.stringify(scenarioMeta, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'scenario_suspects.json'),
    JSON.stringify(suspects, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'scenario_motives.json'),
    JSON.stringify(motives, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'scenario_placeTemplates.json'),
    JSON.stringify(placeTemplates, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'scenario_clueSystem.json'),
    JSON.stringify(clueSystem, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'last_locked_scenario.json'),
    JSON.stringify(lastLockedScenario, null, 2),
    'utf8'
  );

  console.log('');
  console.log('✅ SAUVEGARDE TERMINÉE');
  console.log('📁 Dossier :', outDir);
  console.log('📄 Fichiers :');
  console.log(' - scenario_meta.json');
  console.log(' - scenario_suspects.json');
  console.log(' - scenario_motives.json');
  console.log(' - scenario_placeTemplates.json');
  console.log(' - scenario_clueSystem.json');
  console.log(' - last_locked_scenario.json');
}

backupRuntimeState().catch((error) => {
  console.error('');
  console.error('❌ ERREUR :');
  console.error(error);
  process.exit(1);
});