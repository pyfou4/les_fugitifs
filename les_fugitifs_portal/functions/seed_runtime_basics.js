const admin = require('firebase-admin');

// ===============================
// CONFIGURATION
// ===============================
const scenarioId = 'les_fugitifs';
const serviceAccount = require('./serviceAccountKey.json');

// ===============================
// FIREBASE INIT
// ===============================
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

// ===============================
// DONNÉES
// ===============================
const clueSystemMain = {
  revealRules: {
    strong: { optionCount: 1, trueCount: 1 },
    medium: { optionCount: 2, trueCount: 1 },
    weak: { optionCount: 3, trueCount: 1 },
  },
  contentRules: {
    suspect: { nameWeight: 30, attributeWeight: 70 },
    motive: { nameWeight: 30, attributeWeight: 70 },
  },
};

const placeTemplateA0 = {
  id: 'A0',
  placeType: 'media',
  trigger: {
    type: 'auto_on_enter',
    delayMs: 0,
    retryPolicy: 'none',
    params: {},
  },
  challenge: {
    type: 'media_playback',
    taskDescription: 'Visionner entièrement la séquence.',
    interactionMode: 'passive',
    params: {
      mediaKind: 'video',
      completionMode: 'play_to_end',
      clue: {
        target: 'suspect',
        mode: 'fixed_strength',
        strength: 'medium',
      },
    },
  },
  outro: {
    enabled: false,
    format: 'none',
    narrativeRole: 'transition',
    requiresMedia: false,
  },
  mediaRequirements: {
    intro: { enabled: false, acceptedFormats: [] },
    challenge: { enabled: true, acceptedFormats: ['video'] },
    outro: { enabled: false, acceptedFormats: [] },
  },
};

// ===============================
// ÉCRITURE
// ===============================
async function seed() {
  const scenarioRef = db.collection('scenarios').doc(scenarioId);

  console.log('📡 Connexion Firestore...');
  console.log('🎯 Scenario :', scenarioId);

  const batch = db.batch();

  batch.set(
    scenarioRef.collection('clueSystem').doc('main'),
    clueSystemMain,
    { merge: true }
  );

  batch.set(
    scenarioRef.collection('placeTemplates').doc('A0'),
    placeTemplateA0,
    { merge: true }
  );

  await batch.commit();

  console.log('');
  console.log('✅ TERMINÉ');
  console.log('clueSystem + A0 créés automatiquement');
}

seed().catch((e) => {
  console.error('');
  console.error('❌ ERREUR :');
  console.error(e);
});