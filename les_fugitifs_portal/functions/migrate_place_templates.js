const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

const GAME_ID = 'les_fugitifs';

function mapPlaceType(experienceType) {
  if (experienceType === 'media') return 'media';
  if (experienceType === 'physical') return 'physical';
  if (experienceType === 'observation') return 'observation';
  return 'media';
}

function pickDefaultStrength(place) {
  const allowed = Array.isArray(place.allowedClueStrengths)
    ? place.allowedClueStrengths
    : [];

  if (allowed.includes('medium')) return 'medium';
  if (allowed.includes('strong')) return 'strong';
  if (allowed.includes('weak')) return 'weak';
  return 'medium';
}

function pickDefaultTarget(place) {
  if (place.targetType === 'suspect' || place.targetType === 'motive') {
    return place.targetType;
  }

  if (Array.isArray(place.targets) && place.targets.length > 0) {
    const first = place.targets.find(
      (t) => t && (t.targetType === 'suspect' || t.targetType === 'motive')
    );
    if (first) return first.targetType;
  }

  return 'suspect';
}

function buildClue(place) {
  const isPhysical = place.experienceType === 'physical';

  if (isPhysical) {
    return {
      target: pickDefaultTarget(place),
      mode: 'score_based',
      clueStrengthRules: [
        { min: 0, max: 5, strength: 'weak' },
        { min: 6, max: 8, strength: 'medium' },
        { min: 9, max: 10, strength: 'strong' },
      ],
    };
  }

  return {
    target: pickDefaultTarget(place),
    mode: 'fixed_strength',
    strength: pickDefaultStrength(place),
  };
}

function buildTrigger(place) {
  if (place.id === 'A0') {
    return {
      type: 'auto_on_enter',
      delayMs: 0,
      retryPolicy: 'none',
      params: {},
    };
  }

  return {
    type: 'manual_start',
    delayMs: 0,
    retryPolicy: 'none',
    params: {
      startLabel: 'Commencer',
    },
  };
}

function buildOutro() {
  return {
    enabled: false,
    format: 'none',
    narrativeRole: 'transition',
    requiresMedia: false,
  };
}

function buildMediaRequirements(place) {
  const isMedia = place.experienceType === 'media';

  return {
    intro: {
      enabled: false,
      acceptedFormats: [],
    },
    challenge: {
      enabled: isMedia,
      acceptedFormats: isMedia ? ['video'] : [],
    },
    outro: {
      enabled: false,
      acceptedFormats: [],
    },
  };
}

function buildChallenge(place) {
  const exp = place.experienceType || 'media';
  const clue = buildClue(place);
  const taskDescription =
    place.mediaDescription ||
    place.synopsis ||
    place.storySynopsis ||
    '';

  if (exp === 'media') {
    return {
      type: 'media_playback',
      taskDescription,
      interactionMode: 'passive',
      params: {
        mediaKind: 'video',
        completionMode: 'play_to_end',
        clue,
      },
    };
  }

  if (exp === 'observation') {
    return {
      type: 'observation_validation',
      taskDescription,
      interactionMode: 'confirmation_only',
      params: {
        prompt:
          place.synopsis ||
          place.storySynopsis ||
          'Observez le lieu puis confirmez votre découverte.',
        confirmLabel: 'Confirmer',
        clue,
      },
    };
  }

  if (exp === 'physical') {
    return {
      type: 'physical_task',
      taskDescription,
      interactionMode: 'numeric_input',
      params: {
        scoreMin: 0,
        scoreMax: 10,
        clue,
      },
    };
  }

  return {
    type: 'media_playback',
    taskDescription,
    interactionMode: 'passive',
    params: {
      mediaKind: 'video',
      completionMode: 'play_to_end',
      clue,
    },
  };
}

function buildRuntime(place) {
  return {
    placeType: mapPlaceType(place.experienceType),
    trigger: buildTrigger(place),
    challenge: buildChallenge(place),
    outro: buildOutro(),
    mediaRequirements: buildMediaRequirements(place),
  };
}

async function migrate() {
  console.log('📡 Lecture depuis games...');

  const sourceRef = db
    .collection('games')
    .doc(GAME_ID)
    .collection('placeTemplates');

  const targetRef = db
    .collection('scenarios')
    .doc(GAME_ID)
    .collection('placeTemplates');

  const snap = await sourceRef.get();

  console.log(`📦 ${snap.size} postes trouvés`);

  if (snap.empty) {
    console.log('❌ Aucun poste trouvé dans games/placeTemplates');
    return;
  }

  const batch = db.batch();

  snap.docs.forEach((doc) => {
    const data = doc.data();

    const enriched = {
      ...data,
      id: doc.id,
      ...buildRuntime(data),
    };

    batch.set(targetRef.doc(doc.id), enriched, { merge: true });
  });

  await batch.commit();

  console.log('✅ Migration terminée');
  console.log('👉 Les placeTemplates de scenarios ont été enrichis/corrigés');
}

migrate().catch((e) => {
  console.error('❌ ERREUR :', e);
  process.exit(1);
});