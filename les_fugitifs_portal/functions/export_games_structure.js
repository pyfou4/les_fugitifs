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

async function exportGamesStructure() {
  const outDir = path.join(__dirname, 'firestore_dump');
  fs.mkdirSync(outDir, { recursive: true });

  const gameId = 'les_fugitifs';
  const gameRef = db.collection('games').doc(gameId);

  console.log('📡 Connexion à Firestore...');
  console.log('🎯 Export lecture seule de games/' + gameId);

  const [
    gameSnap,
    suspectsSnap,
    motivesSnap,
    placeTemplatesSnap,
  ] = await Promise.all([
    gameRef.get(),
    gameRef.collection('suspects').get(),
    gameRef.collection('motives').get(),
    gameRef.collection('placeTemplates').get(),
  ]);

  const gameMeta = gameSnap.exists
    ? { id: gameSnap.id, ...gameSnap.data() }
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

  fs.writeFileSync(
    path.join(outDir, 'games_meta.json'),
    JSON.stringify(gameMeta, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'games_suspects.json'),
    JSON.stringify(suspects, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'games_motives.json'),
    JSON.stringify(motives, null, 2),
    'utf8'
  );

  fs.writeFileSync(
    path.join(outDir, 'games_placeTemplates.json'),
    JSON.stringify(placeTemplates, null, 2),
    'utf8'
  );

  console.log('');
  console.log('✅ EXPORT TERMINÉ');
  console.log('📁 Dossier :', outDir);
  console.log('📄 Fichiers :');
  console.log(' - games_meta.json');
  console.log(' - games_suspects.json');
  console.log(' - games_motives.json');
  console.log(' - games_placeTemplates.json');
}

exportGamesStructure().catch((error) => {
  console.error('');
  console.error('❌ ERREUR :');
  console.error(error);
  process.exit(1);
});