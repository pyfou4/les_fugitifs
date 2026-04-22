const admin = require('firebase-admin');
const db = admin.firestore();

const { validatePlaceTemplates } = require('../validators/placeTemplates');

async function lockScenario({ scenarioId, adminUid }) {
  if (!scenarioId || typeof scenarioId !== 'string') {
    throw new Error('scenarioId is required');
  }

  if (!adminUid || typeof adminUid !== 'string') {
    throw new Error('adminUid is required');
  }

  const scenarioRef = db.collection('scenarios').doc(scenarioId);
  const lockedScenariosRef = db.collection('lockedScenarios');

  const scenarioSnap = await scenarioRef.get();

  if (!scenarioSnap.exists) {
    throw new Error(`Scenario not found: ${scenarioId}`);
  }

  const scenarioData = scenarioSnap.data() || {};

  const [
    suspectsSnap,
    motivesSnap,
    placeTemplatesSnap,
    clueSystemSnap,
  ] = await Promise.all([
    scenarioRef.collection('suspects').get(),
    scenarioRef.collection('motives').get(),
    scenarioRef.collection('placeTemplates').get(),
    scenarioRef.collection('clueSystem').doc('main').get(),
  ]);

  const suspectsSourceList = suspectsSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const motivesSourceList = motivesSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const placeTemplatesSourceList = placeTemplatesSnap.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));

  const clueSystem = clueSystemSnap.exists ? clueSystemSnap.data() : null;

  const presenceErrors = [];

  if (suspectsSourceList.length === 0) {
    presenceErrors.push('No suspects found in scenarios/{scenarioId}/suspects');
  }

  if (motivesSourceList.length === 0) {
    presenceErrors.push('No motives found in scenarios/{scenarioId}/motives');
  }

  if (!clueSystem) {
    presenceErrors.push('Missing clueSystem at scenarios/{scenarioId}/clueSystem/main');
  }

  if (placeTemplatesSourceList.length === 0) {
    presenceErrors.push('No placeTemplates found in scenarios/{scenarioId}/placeTemplates');
  }

  if (presenceErrors.length > 0) {
    return {
      success: false,
      stage: 'presence_check',
      validation: {
        isValid: false,
        errors: presenceErrors,
        warnings: [],
      },
    };
  }

  const suspectsMap = indexById(
    suspectsSourceList.map(transformSuspectToRuntime)
  );

  const motivesMap = indexById(
    motivesSourceList.map(transformMotiveToRuntime)
  );

  const placeTemplatesMap = indexById(placeTemplatesSourceList);

  const clueSystemValidation = validateClueSystem(clueSystem);
  const suspectsValidation = validateRuntimeEntitiesMap(suspectsMap, 'suspects');
  const motivesValidation = validateRuntimeEntitiesMap(motivesMap, 'motives');
  const placeTemplatesValidation = validatePlaceTemplates(placeTemplatesMap);

  const combinedErrors = [
    ...clueSystemValidation.errors,
    ...suspectsValidation.errors,
    ...motivesValidation.errors,
    ...placeTemplatesValidation.errors,
  ];

  const combinedWarnings = [
    ...clueSystemValidation.warnings,
    ...suspectsValidation.warnings,
    ...motivesValidation.warnings,
    ...placeTemplatesValidation.warnings,
  ];

  if (combinedErrors.length > 0) {
    return {
      success: false,
      stage: 'global_validation',
      validation: {
        isValid: false,
        errors: combinedErrors,
        warnings: combinedWarnings,
      },
    };
  }

  const now = new Date();
  const nowIso = now.toISOString();
  const version = Number.isInteger(scenarioData.lockVersion)
    ? scenarioData.lockVersion + 1
    : 1;

  const lockedScenarioId = buildLockedScenarioId({
    scenarioId,
    version,
    now,
  });

  const lockedScenarioPayload = {
    id: lockedScenarioId,
    sourceScenarioId: scenarioId,
    version,
    createdAt: nowIso,
    createdBy: adminUid,
    status: 'locked',
    data: {
      clueSystem,
      suspects: suspectsMap,
      motives: motivesMap,
      placeTemplates: placeTemplatesMap,
    },
    validation: {
      isValid: true,
      errors: [],
      warnings: combinedWarnings,
      version: 1,
    },
  };

  await db.runTransaction(async (tx) => {
    const lockedScenarioRef = lockedScenariosRef.doc(lockedScenarioId);

    tx.set(lockedScenarioRef, lockedScenarioPayload);

    tx.update(scenarioRef, {
      lastLockedScenarioId: lockedScenarioId,
      lastLockedAt: nowIso,
      lockVersion: version,
    });
  });

  return {
    success: true,
    lockedScenarioId,
    version,
    validation: {
      isValid: true,
      errors: [],
      warnings: combinedWarnings,
    },
  };
}

function transformSuspectToRuntime(source) {
  const title = normalizeSingleLineText(source.name || source.title || source.id);
  const attributes = buildSuspectAttributes(source);
  const mediaKey = normalizeSingleLineText(source.image || source.imagePath || '');

  return {
    id: source.id,
    title,
    attributes,
    identityVisual: {
      mediaKey,
    },
  };
}

function transformMotiveToRuntime(source) {
  const title = normalizeSingleLineText(source.name || source.title || source.id);
  const attributes = buildMotiveAttributes(source);
  const mediaKey = normalizeSingleLineText(source.image || source.imagePath || '');

  return {
    id: source.id,
    title,
    attributes,
    identityVisual: {
      mediaKey,
    },
  };
}

function buildSuspectAttributes(source) {
  const attributes = [];

  if (source.age !== undefined && source.age !== null && source.age !== '') {
    if (Number.isFinite(Number(source.age))) {
      attributes.push(`${Number(source.age)} ans`);
    } else {
      attributes.push(normalizeSingleLineText(String(source.age)));
    }
  }

  if (isNonEmptyString(source.profession)) {
    attributes.push(cleanQuotedText(source.profession));
  }

  const buildParts = splitBuildParts(source.build);
  attributes.push(...buildParts);

  return uniqueNonEmptyStrings(attributes);
}

function buildMotiveAttributes(source) {
  const attributes = [];

  if (isNonEmptyString(source.preparations)) {
    attributes.push(`Préparation : ${cleanQuotedText(source.preparations)}`);
  }

  if (isNonEmptyString(source.delays)) {
    attributes.push(`Délais : ${cleanQuotedText(source.delays)}`);
  }

  if (isNonEmptyString(source.violence)) {
    attributes.push(`Violence : ${cleanQuotedText(source.violence)}`);
  }

  return uniqueNonEmptyStrings(attributes);
}

function splitBuildParts(buildValue) {
  if (!isNonEmptyString(buildValue)) {
    return [];
  }

  const rawParts = String(buildValue)
    .split('/')
    .map((part) => normalizeSingleLineText(part))
    .filter(Boolean);

  return rawParts.map(formatBuildPart);
}

function formatBuildPart(value) {
  const lower = value.toLowerCase();

  const startsWithHair =
    lower.startsWith('cheveux') ||
    lower.startsWith('barbe') ||
    lower.startsWith('moustache') ||
    lower.startsWith('yeux');

  if (startsWithHair) {
    return value;
  }

  return `silhouette ${value}`;
}

function validateClueSystem(clueSystem) {
  const errors = [];
  const warnings = [];

  if (!isPlainObject(clueSystem)) {
    errors.push('clueSystem must be an object');
    return { isValid: false, errors, warnings };
  }

  const revealRules = clueSystem.revealRules;
  const contentRules = clueSystem.contentRules;

  if (!isPlainObject(revealRules)) {
    errors.push('clueSystem.revealRules must be an object');
  } else {
    ['strong', 'medium', 'weak'].forEach((key) => {
      const rule = revealRules[key];
      if (!isPlainObject(rule)) {
        errors.push(`clueSystem.revealRules.${key} must be an object`);
        return;
      }

      if (!Number.isInteger(rule.optionCount)) {
        errors.push(`clueSystem.revealRules.${key}.optionCount must be an integer`);
      }

      if (!Number.isInteger(rule.trueCount)) {
        errors.push(`clueSystem.revealRules.${key}.trueCount must be an integer`);
      }
    });
  }

  if (!isPlainObject(contentRules)) {
    errors.push('clueSystem.contentRules must be an object');
  } else {
    ['suspect', 'motive'].forEach((key) => {
      const rule = contentRules[key];
      if (!isPlainObject(rule)) {
        errors.push(`clueSystem.contentRules.${key} must be an object`);
        return;
      }

      if (!Number.isInteger(rule.nameWeight)) {
        errors.push(`clueSystem.contentRules.${key}.nameWeight must be an integer`);
      }

      if (!Number.isInteger(rule.attributeWeight)) {
        errors.push(`clueSystem.contentRules.${key}.attributeWeight must be an integer`);
      }
    });
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

function validateRuntimeEntitiesMap(entityMap, label) {
  const errors = [];
  const warnings = [];

  if (!isPlainObject(entityMap)) {
    errors.push(`${label} must be an object map`);
    return { isValid: false, errors, warnings };
  }

  const entries = Object.entries(entityMap);

  if (entries.length === 0) {
    errors.push(`${label} must not be empty`);
    return { isValid: false, errors, warnings };
  }

  for (const [entityId, entity] of entries) {
    const path = `${label}.${entityId}`;

    if (!isPlainObject(entity)) {
      errors.push(`${path} must be an object`);
      continue;
    }

    requireString(entity.id, `${path}.id`, errors);
    requireString(entity.title, `${path}.title`, errors);

    if (!Array.isArray(entity.attributes) || entity.attributes.length === 0) {
      errors.push(`${path}.attributes must be a non-empty array`);
    } else {
      entity.attributes.forEach((value, index) => {
        if (!isNonEmptyString(value)) {
          errors.push(`${path}.attributes[${index}] must be a non-empty string`);
        }
      });
    }

    if (!isPlainObject(entity.identityVisual)) {
      errors.push(`${path}.identityVisual must be an object`);
    } else {
      requireString(
        entity.identityVisual.mediaKey,
        `${path}.identityVisual.mediaKey`,
        errors
      );
    }

    if (entity.id !== entityId) {
      errors.push(`${path} map key must equal ${label.slice(0, -1)}.id`);
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
  };
}

function indexById(items) {
  const result = {};

  for (const item of items) {
    if (!item || typeof item !== 'object') {
      continue;
    }

    if (!item.id || typeof item.id !== 'string') {
      continue;
    }

    result[item.id] = item;
  }

  return result;
}

function buildLockedScenarioId({ scenarioId, version, now }) {
  const yyyy = String(now.getUTCFullYear());
  const mm = String(now.getUTCMonth() + 1).padStart(2, '0');
  const dd = String(now.getUTCDate()).padStart(2, '0');
  const hh = String(now.getUTCHours()).padStart(2, '0');
  const min = String(now.getUTCMinutes()).padStart(2, '0');
  const sec = String(now.getUTCSeconds()).padStart(2, '0');

  return `${scenarioId}_locked_v${version}_${yyyy}${mm}${dd}_${hh}${min}${sec}`;
}

function normalizeSingleLineText(value) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanQuotedText(value) {
  return normalizeSingleLineText(String(value || '').replace(/^"+|"+$/g, ''));
}

function uniqueNonEmptyStrings(values) {
  const result = [];
  const seen = new Set();

  for (const value of values) {
    const clean = normalizeSingleLineText(value);
    if (!clean) continue;

    const key = clean.toLowerCase();
    if (seen.has(key)) continue;

    seen.add(key);
    result.push(clean);
  }

  return result;
}

function isNonEmptyString(value) {
  return typeof value === 'string' && value.trim() !== '';
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function requireString(value, path, errors) {
  if (!isNonEmptyString(value)) {
    errors.push(`${path} must be a non-empty string`);
  }
}

module.exports = {
  lockScenario,
};