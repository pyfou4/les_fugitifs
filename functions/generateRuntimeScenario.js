const admin = require("firebase-admin");
const fs = require("fs");

const serviceAccount = require("../serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

/* =========================
   CONFIG
========================= */

const GAME_ID = "les_fugitifs";

/* =========================
   HELPERS
========================= */

function mapType(place) {
  return place.placeType || place.experienceType;
}

function mapMechanic(place) {
  const challenge = place.challenge || {};

  return {
    mode:
      challenge.type === "physical_task"
        ? "score"
        : challenge.type === "media_playback"
        ? "passive"
        : "answer",
    interaction: challenge.interactionMode || "none",
    rules: challenge.params || {}
  };
}

function mapScoring(place) {
  const clue = place.challenge?.params?.clue;

  if (!clue || !clue.clueStrengthRules) return null;

  return {
    type: "threshold",
    thresholds: clue.clueStrengthRules.map((r) => ({
      min: r.min,
      max: r.max,
      result: r.strength
    }))
  };
}

function mapReward(place) {
  const clue = place.challenge?.params?.clue;

  if (!clue) return null;

  const targetType = clue.target || place.targetType || null;
  const targetSlot =
    place.targetSlot ||
    firstTargetSlotForType(place.targets, targetType) ||
    null;

  return {
    mode: clue.mode || "fixed",
    targetType,
    targetSlot
  };
}

function firstTargetSlotForType(targets, targetType) {
  if (!Array.isArray(targets)) return null;

  const normalizedTargetType = normalizeTargetType(targetType);

  const matchingTarget = targets.find((target) => {
    if (!target || typeof target !== "object") return false;
    return normalizeTargetType(target.targetType) === normalizedTargetType;
  });

  if (matchingTarget?.targetSlot) {
    return matchingTarget.targetSlot;
  }

  const firstTarget = targets.find((target) => target?.targetSlot);
  return firstTarget?.targetSlot || null;
}

function normalizeTargetType(value) {
  const normalized = (value || "").toString().trim().toLowerCase();
  if (normalized === "suspect" || normalized === "pc") return "suspect";
  if (normalized === "motive" || normalized === "mobile" || normalized === "mo") {
    return "motive";
  }
  return normalized;
}

function mapVisibility(place) {
  return {
    requiresAll: place.requiresAllVisited || [],
    requiresAny: place.requiresAnyVisited || [],
    unlockRules: place.unlockRules || null
  };
}

function mapNarration(place) {
  return {
    description: place.storySynopsis || "",
    brief: place.synopsis || "",
    successText: null,
    failureText: null
  };
}

function mapTrigger(place) {
  return place.trigger || { type: "manual_start" };
}

function mapMedia(place) {
  return {
    hasIntro: place.mediaRequirements?.intro?.enabled || false,
    hasOutro: place.mediaRequirements?.outro?.enabled || false,
    hasChallengeMedia: place.mediaRequirements?.challenge?.enabled || false
  };
}

function buildRuntimePlace(place) {
  return {
    id: place.id,
    phase: place.phase,
    order: place.phaseIndex || 0,
    title: place.title || place.name,

    location: null, // ⚠️ on ne touche pas à la géo pour l'instant

    visibility: mapVisibility(place),
    type: mapType(place),

    narration: mapNarration(place),
    mechanic: mapMechanic(place),
    scoring: mapScoring(place),
    reward: mapReward(place),
    trigger: mapTrigger(place),
    media: mapMedia(place),

    // Données conservées pour le moteur de fin de poste.
    // Elles ne recréent aucune règle : elles transportent le contrat scénariste.
    allowedClueStrengths: place.allowedClueStrengths || [],
    targets: Array.isArray(place.targets) ? place.targets : [],
    targetSelectionMode: place.targetSelectionMode || null
  };
}

/* =========================
   MAIN
========================= */

async function generateRuntimeScenario() {
  console.log("🚀 Génération runtime scenario...");

  // 1. récupérer game
  const gameRef = db.collection("games").doc(GAME_ID);
  const gameDoc = await gameRef.get();

  if (!gameDoc.exists) {
    throw new Error("Game introuvable");
  }

  const game = gameDoc.data();
  const lockedId = game.lastLockedScenarioId;

  if (!lockedId) {
    throw new Error("Aucun lockedScenario référencé");
  }

  console.log("📦 LockedScenario:", lockedId);

  // 2. récupérer lockedScenario
  const lockedRef = db.collection("lockedScenarios").doc(lockedId);
  const lockedDoc = await lockedRef.get();

  if (!lockedDoc.exists) {
    throw new Error("LockedScenario introuvable");
  }

  const locked = lockedDoc.data();

  // =========================
  // EXTRACTION CLUE SYSTEM + ENTITÉS LOCKÉES
  // =========================

  const clueSystem = locked.data?.clueSystem || locked.clueSystem || null;
  const suspects = locked.data?.suspects || locked.suspects || [];
  const motives = locked.data?.motives || locked.motives || [];
  const placesMap = locked.data?.placeTemplates;

  if (!placesMap) {
    throw new Error("placeTemplates introuvable");
  }

  const places = Object.values(placesMap);

  console.log(`📍 ${places.length} places trouvées`);

  // 3. transformation
  const runtimePlaces = places.map(buildRuntimePlace);

  // 4. création runtime
  const runtimeId = `runtime_${Date.now()}`;

  const runtimeData = {
    id: runtimeId,
    gameId: GAME_ID,
    sourceLockedScenarioId: lockedId,
    version: 1,
    status: "active",
    generatedAt: new Date().toISOString(),

    // Données globales nécessaires au runtime Flutter
    // Elles existent déjà dans le lockedScenario : on les transporte sans les réinventer.
    clueSystem,
    suspects,
    motives,

    places: runtimePlaces
  };

  // 5. écriture Firestore
  await db.collection("runtime_scenarios").doc(runtimeId).set(runtimeData);

  // 6. mise à jour du pointeur
  await gameRef.update({
    lastRuntimeScenarioId: runtimeId
  });

  console.log("✅ Runtime scenario créé:", runtimeId);
}

generateRuntimeScenario()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("❌ ERREUR:", err);
    process.exit(1);
  });