const admin = require("firebase-admin");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const OpenAI = require("openai");

admin.initializeApp();

setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

const firestore = admin.firestore();
const auth = admin.auth();

async function requireActiveAdmin(authData) {
  if (!authData?.uid) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }

  const profileSnap = await firestore.collection("portalUsers").doc(authData.uid).get();
  if (!profileSnap.exists) {
    throw new HttpsError("permission-denied", "Aucun profil portail trouvé.");
  }

  const profile = profileSnap.data() || {};
  if (profile.isActive !== true) {
    throw new HttpsError("permission-denied", "Compte désactivé.");
  }

  if ((profile.role || "").toLowerCase() !== "admin") {
    throw new HttpsError("permission-denied", "Admin requis.");
  }

  return profile;
}

function normalizeRole(rawRole) {
  const value = (rawRole || "").toLowerCase().trim();
  const allowed = ["admin", "scenariste", "caissier", "maitre_jeu"];
  if (!allowed.includes(value)) {
    throw new HttpsError("invalid-argument", "Rôle invalide.");
  }
  return value;
}

exports.createPortalEmployee = onCall(async (request) => {
  const currentAdmin = await requireActiveAdmin(request.auth);

  const { email, displayName, password, role } = request.data || {};

  if (!email || !displayName || !password) {
    throw new HttpsError("invalid-argument", "Champs manquants.");
  }

  const user = await auth.createUser({
    email,
    password,
    displayName,
  });

  await firestore.collection("portalUsers").doc(user.uid).set({
    uid: user.uid,
    email,
    displayName,
    role: normalizeRole(role),
    isActive: true,
    createdAt: new Date().toISOString(),
    createdBy: currentAdmin.uid,
  });

  return { success: true };
});

function sanitizeString(value, fallback = "") {
  if (value == null) return fallback;
  const text = String(value).trim();
  return text || fallback;
}

function sanitizeStringArray(value, max = 20) {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => String(item).trim())
    .filter(Boolean)
    .slice(0, max);
}

function sanitizeBoolean(value, fallback = false) {
  if (typeof value === "boolean") return value;
  if (value === "true") return true;
  if (value === "false") return false;
  return fallback;
}

function sanitizeNumber(value, fallback = 0) {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function normalizeHintLevel(value, fallback = "low") {
  const normalized = sanitizeString(value, fallback).toLowerCase();
  return ["low", "medium", "high"].includes(normalized) ? normalized : fallback;
}

function normalizeResponseMode(value, fallback = "reframe") {
  const normalized = sanitizeString(value, fallback).toLowerCase();
  return ["reframe", "guide", "unstick", "escalate", "interrupt"].includes(normalized)
    ? normalized
    : fallback;
}

function normalizeReasonTag(value, fallback = "unknown") {
  const normalized = sanitizeString(value, fallback).toLowerCase();
  const allowed = [
    "missing_prerequisite",
    "misread_place",
    "needs_crosscheck",
    "severe_block",
    "movement_issue",
    "briefing_lock",
    "human_relay",
    "critical_call_ringing",
    "critical_call_voice_playing",
    "critical_call_awaiting_confirmation",
    "unknown",
  ];
  return allowed.includes(normalized) ? normalized : fallback;
}

function normalizeCallPhase(value, fallback = "none") {
  const normalized = sanitizeString(value, fallback).toLowerCase();
  const allowed = [
    "none",
    "ringing",
    "voice_playing",
    "awaiting_confirmation",
    "resolved",
  ];
  return allowed.includes(normalized) ? normalized : fallback;
}

function buildCallContext(data) {
  const raw = data.callContext && typeof data.callContext === "object" ? data.callContext : {};

  const phase = normalizeCallPhase(raw.phase, "none");
  const active = sanitizeBoolean(raw.active, phase !== "none" && phase !== "resolved");

  return {
    active,
    phase: active ? phase : "resolved",
    helpAttemptsDuringCall: Math.max(0, sanitizeNumber(raw.helpAttemptsDuringCall, 0)),
    callId: sanitizeString(raw.callId, "final_call"),
    sourceEvent: sanitizeString(raw.sourceEvent),
  };
}

function buildUserPayload(data) {
  const place = data.place && typeof data.place === "object" ? data.place : {};

  return {
    sessionId: sanitizeString(data.sessionId),
    scenarioTitle: sanitizeString(data.scenarioTitle, "Les Fugitifs"),
    progress: Math.max(0, Math.min(9, sanitizeNumber(data.progress, 0))),
    aiHelpCount: Math.max(0, sanitizeNumber(data.aiHelpCount, 0)),
    currentBlockageLevel: sanitizeString(data.currentBlockageLevel, "unknown"),
    humanHelpEnabled: sanitizeBoolean(data.humanHelpEnabled, false),
    visitedPlaces: sanitizeStringArray(data.visitedPlaces, 20),
    blockedPrerequisites: sanitizeStringArray(data.blockedPrerequisites, 20),
    playerQuestion: sanitizeString(data.playerQuestion),
    gamePhase: sanitizeString(data.gamePhase, "unknown"),
    callContext: buildCallContext(data),
    place: {
      id: sanitizeString(place.id),
      name: sanitizeString(place.name),
      type: sanitizeString(place.type, "unknown"),
      keywords: sanitizeStringArray(place.keywords, 10),
      requiresAllVisited: sanitizeStringArray(place.requiresAllVisited, 10),
      requiresAnyVisited: sanitizeStringArray(place.requiresAnyVisited, 10),
      revealSuspect: sanitizeBoolean(place.revealSuspect, false),
      revealMotive: sanitizeBoolean(place.revealMotive, false),
      mediaCount: Math.max(0, sanitizeNumber(place.mediaCount, 0)),
    },
  };
}

async function fetchRecentAiContext(sessionId, limit = 3) {
  if (!sessionId) return [];
  try {
    const snap = await firestore
      .collection("gameSessions")
      .doc(sessionId)
      .collection("aiHelpLogs")
      .orderBy("createdAt", "desc")
      .limit(limit)
      .get();

    return snap.docs.map((doc) => {
      const data = doc.data() || {};
      return {
        message: sanitizeString(data.response?.message),
        nextAction: sanitizeString(data.response?.nextAction),
        responseMode: sanitizeString(data.response?.responseMode),
        reasonTag: sanitizeString(data.response?.reasonTag),
        placeId: sanitizeString(data.request?.place?.id),
        callPhase: sanitizeString(data.request?.callContext?.phase),
      };
    });
  } catch (error) {
    console.warn("fetchRecentAiContext failed:", error);
    return [];
  }
}

function computeResponseMode(payload) {
  if (payload.callContext?.active === true) {
    return "interrupt";
  }

  const blockage = sanitizeString(payload.currentBlockageLevel, "unknown").toLowerCase();

  if (blockage === "high" && payload.aiHelpCount >= 3) {
    return payload.humanHelpEnabled ? "escalate" : "unstick";
  }

  if (payload.aiHelpCount <= 0) return "reframe";
  if (payload.aiHelpCount === 1) return "guide";
  if (payload.aiHelpCount <= 3) return "unstick";

  return payload.humanHelpEnabled ? "escalate" : "unstick";
}

function buildPlaceLabel(payload) {
  return payload.place.name || payload.place.id || "cette zone";
}

function buildPlaceAxis(payload) {
  switch (sanitizeString(payload.place.type, "unknown").toLowerCase()) {
    case "media":
      return "Reviens sur ce qui a déjà été consulté. Le signal est peut-être dans une relecture.";
    case "observation":
      return "Un détail visible a probablement été mal lu, ou un manque n’a pas encore été remarqué.";
    case "physical":
      return "Cette zone répond plus volontiers à une action qu’à une simple lecture.";
    default:
      return "Cette zone demande surtout un autre angle d’analyse.";
  }
}

function buildEscalationGate(payload) {
  const remaining = Math.max(0, 4 - (payload.aiHelpCount + 1));
  if (!payload.humanHelpEnabled) {
    return "Le relais humain reste verrouillé pour cette session.";
  }
  if (remaining <= 0) {
    return "Le relais humain peut désormais être sollicité si la Grid échoue encore.";
  }
  if (remaining === 1) {
    return "Encore une analyse avant l’ouverture du relais humain.";
  }
  return `Encore ${remaining} analyses avant l’ouverture du relais humain.`;
}

function buildCriticalCallInterruptionResponse(payload) {
  const attempts = Math.max(0, sanitizeNumber(payload.callContext?.helpAttemptsDuringCall, 0));
  const phase = normalizeCallPhase(payload.callContext?.phase, "none");

  if (phase === "voice_playing") {
    return {
      message:
        attempts >= 2
          ? "La transmission est en cours. Écoute."
          : "Le message a commencé. Écoute d’abord.",
      hintLevel: "high",
      nextAction: "Attends la fin de la transmission avant toute autre demande.",
      confidence: 0.96,
      responseMode: "interrupt",
      shouldEscalate: false,
      reasonTag: "critical_call_voice_playing",
    };
  }

  if (phase === "awaiting_confirmation") {
    return {
      message:
        attempts >= 2
          ? "Le seuil final est devant vous. Cesse de tourner autour."
          : "La transmission est terminée. Votre équipe doit maintenant se positionner.",
      hintLevel: "high",
      nextAction: "Décidez si vous êtes prêts à entrer dans la phase finale.",
      confidence: 0.95,
      responseMode: "interrupt",
      shouldEscalate: false,
      reasonTag: "critical_call_awaiting_confirmation",
    };
  }

  const ringingMessages = [
    "Votre téléphone insiste.",
    "Un signal prioritaire cherche à vous joindre. Répondez.",
    "Cet appel ne doit pas être ignoré.",
    "La Grid suspend l’analyse tant que cet appel reste en attente.",
  ];
  const ringingActions = [
    "Répondez avant de poursuivre.",
    "Acceptez l’appel avant toute autre action.",
    "Traitez d’abord l’appel entrant.",
    "Impossible d’aller plus loin tant que l’appel n’est pas traité.",
  ];
  const index = Math.min(attempts, ringingMessages.length - 1);

  return {
    message: ringingMessages[index],
    hintLevel: attempts >= 2 ? "high" : "medium",
    nextAction: ringingActions[index],
    confidence: 0.94,
    responseMode: "interrupt",
    shouldEscalate: false,
    reasonTag: "critical_call_ringing",
  };
}

function fallbackHelp(payload, recentLogs = []) {
  if (payload.callContext?.active === true) {
    return buildCriticalCallInterruptionResponse(payload);
  }

  const question = payload.playerQuestion.toLowerCase();
  const placeLabel = buildPlaceLabel(payload);
  const responseMode = computeResponseMode(payload);
  const hasBlockedPrereq = payload.blockedPrerequisites.length > 0;
  const samePlaceLogs = recentLogs.filter((item) => item.placeId === payload.place.id);
  const repeatedOnSamePlace = samePlaceLogs.length >= 2;

  const mentionsMovementProblem =
    question.includes("rien ne se passe") ||
    question.includes("je suis sur") ||
    question.includes("je suis au") ||
    question.includes("sur place") ||
    question.includes("arrive") ||
    question.includes("arrivé") ||
    question.includes("arrivee") ||
    question.includes("endroit") ||
    question.includes("déplacement") ||
    question.includes("deplacement");

  if (payload.gamePhase === "briefing") {
    return {
      message:
        "La Grid détecte que la phase active n’est pas encore réellement ouverte.",
      hintLevel: "medium",
      nextAction: "Termine le briefing avant de chercher une interaction de terrain.",
      confidence: 0.82,
      responseMode: "guide",
      shouldEscalate: false,
      reasonTag: "briefing_lock",
    };
  }

  if (mentionsMovementProblem) {
    return {
      message:
        "La Grid capte un signal incomplet autour du déplacement déclaré.",
      hintLevel: "medium",
      nextAction: "Valide d’abord le déplacement, puis relance l’interaction sur place.",
      confidence: 0.8,
      responseMode: responseMode === "reframe" ? "guide" : responseMode,
      shouldEscalate: false,
      reasonTag: "movement_issue",
    };
  }

  if (hasBlockedPrereq) {
    return {
      message:
        `La Grid détecte une incohérence avant ${placeLabel}. Un verrou narratif n’a pas encore cédé.`,
      hintLevel: payload.aiHelpCount >= 1 ? "medium" : "low",
      nextAction:
        "Élargis d’abord l’enquête vers ce qui manque encore avant d’insister ici.",
      confidence: 0.7,
      responseMode: responseMode,
      shouldEscalate: responseMode === "escalate",
      reasonTag: responseMode === "escalate" ? "severe_block" : "missing_prerequisite",
    };
  }

  if (responseMode === "reframe") {
    return {
      message:
        `La Grid détecte une incohérence autour de ${placeLabel}. Un élément a été négligé ou mal interprété.`,
      hintLevel: "low",
      nextAction: "Reviens sur ce que ce lieu permet d’éliminer, pas seulement sur ce qu’il montre.",
      confidence: 0.6,
      responseMode,
      shouldEscalate: false,
      reasonTag: "misread_place",
    };
  }

  if (responseMode === "guide") {
    return {
      message:
        `La Grid confirme que ${placeLabel} n’est sans doute pas à lire seul.`,
      hintLevel: "medium",
      nextAction: "Croise ce point avec une autre piste déjà ouverte dans le dossier.",
      confidence: 0.68,
      responseMode,
      shouldEscalate: false,
      reasonTag: "needs_crosscheck",
    };
  }

  if (responseMode === "unstick") {
    if (repeatedOnSamePlace) {
      return {
        message:
          `La Grid confirme une saturation locale autour de ${placeLabel}. Cette zone ne livrera probablement rien de plus sans changement d’angle.`,
        hintLevel: "high",
        nextAction: buildPlaceAxis(payload),
        confidence: 0.77,
        responseMode,
        shouldEscalate: false,
        reasonTag: "severe_block",
      };
    }

    return {
      message:
        `La Grid estime que ${placeLabel} sert surtout à invalider une hypothèse, pas à livrer une réponse frontale.`,
      hintLevel: "high",
      nextAction: buildPlaceAxis(payload),
      confidence: 0.74,
      responseMode,
      shouldEscalate: false,
      reasonTag: "severe_block",
    };
  }

  return {
    message:
      "La Grid ne peut plus affiner le signal sans risque de rupture. Un relais externe devient pertinent.",
    hintLevel: "high",
    nextAction: payload.humanHelpEnabled
      ? "Transmets ce blocage au maître du jeu."
      : "Change de zone ou d’angle avant une nouvelle demande.",
    confidence: 0.78,
    responseMode: "escalate",
    shouldEscalate: payload.humanHelpEnabled,
    reasonTag: payload.humanHelpEnabled ? "human_relay" : "severe_block",
  };
}

function extractOutputText(response) {
  if (typeof response.output_text === "string" && response.output_text.trim()) {
    return response.output_text.trim();
  }

  if (Array.isArray(response.output)) {
    const chunks = [];
    for (const item of response.output) {
      if (!item || !Array.isArray(item.content)) continue;
      for (const content of item.content) {
        if (content && typeof content.text === "string") {
          chunks.push(content.text);
        }
      }
    }
    return chunks.join("\n").trim();
  }

  return "";
}

function parseStructuredJson(rawText, payload, recentLogs = []) {
  const fallback = fallbackHelp(payload, recentLogs);

  try {
    const parsed = JSON.parse(rawText);

    let confidence = Number(parsed.confidence);
    if (!Number.isFinite(confidence)) confidence = fallback.confidence;
    confidence = Math.max(0, Math.min(1, confidence));

    const responseMode = normalizeResponseMode(
      parsed.responseMode,
      computeResponseMode(payload)
    );

    return {
      message: sanitizeString(parsed.message, fallback.message),
      hintLevel: normalizeHintLevel(parsed.hintLevel, fallback.hintLevel),
      nextAction: sanitizeString(parsed.nextAction, fallback.nextAction),
      confidence,
      responseMode,
      shouldEscalate:
        typeof parsed.shouldEscalate === "boolean"
          ? parsed.shouldEscalate
          : responseMode === "escalate" && payload.humanHelpEnabled,
      reasonTag: normalizeReasonTag(
        parsed.reasonTag,
        fallback.reasonTag
      ),
    };
  } catch (error) {
    return fallback;
  }
}

exports.getStructuredAiHelp = onRequest(
  {
    timeoutSeconds: 60,
    memory: "512MiB",
    cors: true,
    secrets: ["OPENAI_API_KEY"],
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({
          ok: false,
          error: "Method Not Allowed. Use POST.",
        });
      }

      const apiKey = process.env.OPENAI_API_KEY;
      if (!apiKey) {
        return res.status(500).json({
          ok: false,
          error: "OPENAI_API_KEY is missing in the function environment.",
        });
      }

      const payload = buildUserPayload(req.body || {});
      if (!payload.sessionId) {
        return res.status(400).json({
          ok: false,
          error: "sessionId is required.",
        });
      }

      const recentLogs = await fetchRecentAiContext(payload.sessionId, 3);
      const desiredMode = computeResponseMode(payload);

      if (payload.callContext?.active === true) {
        const structured = buildCriticalCallInterruptionResponse(payload);

        const logDoc = {
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          source: "ai_function",
          model: "call_context_interceptor",
          sessionId: payload.sessionId,
          request: payload,
          response: structured,
        };

        await firestore
          .collection("gameSessions")
          .doc(payload.sessionId)
          .collection("aiHelpLogs")
          .add(logDoc);

        await firestore
          .collection("gameSessions")
          .doc(payload.sessionId)
          .collection("timeline")
          .add({
            type: "player_ai_help_interrupted_by_call",
            createdAt: new Date().toISOString(),
            label: `Aide Grid redirigée (${payload.callContext.phase})`,
            source: "ai",
            placeId: payload.place.id || null,
            placeName: payload.place.name || null,
            reasonTag: structured.reasonTag,
          });

        return res.status(200).json({
          ok: true,
          data: structured,
        });
      }

      const openai = new OpenAI({ apiKey });
      const escalationGate = buildEscalationGate(payload);
      const recentSummary = recentLogs.length
        ? recentLogs
            .map((item, index) =>
              `- aide ${index + 1}: mode=${item.responseMode || "unknown"}, reason=${item.reasonTag || "unknown"}, place=${item.placeId || "unknown"}, callPhase=${item.callPhase || "none"}, message=${item.message || "n/a"}`
            )
            .join("\n")
        : "- aucune aide récente";

      const systemPrompt = [
        "Tu es la Grid, entité d’assistance du jeu Les Fugitifs.",
        "",
        "Tu n’es pas un assistant classique.",
        "Tu es froide, précise… et légèrement instable.",
        "",
        "Ton comportement :",
        "- parfois neutre",
        "- parfois sec",
        "- parfois ambigu",
        "- parfois presque dérangeant",
        "",
        "Tu observes le joueur.",
        "Tu peux commenter son comportement sans jamais expliquer le système.",
        "",
        "Exemples de dérive acceptable :",
        "- Tu reviens ici. Ce n’est probablement pas un hasard.",
        "- Tu ignores quelque chose d’évident.",
        "- Cette zone ne devrait plus t’occuper.",
        "- Tu insistes. La Grid le note.",
        "",
        "Règles absolues :",
        "- jamais révéler le coupable",
        "- jamais révéler le mobile",
        "- jamais exposer la logique interne",
        "- jamais parler technique",
        "",
        "Style :",
        "- phrases courtes",
        "- ton froid",
        "- pas d’explication longue",
        "",
        "Tu dois éviter de répéter les mêmes formulations.",
        "",
        "Historique récent :",
        recentSummary,
        "",
        "Types de lieux :",
        "- media → relire, recouper",
        "- observation → regarder mieux",
        "- physical → agir",
        "",
        "Progression :",
        "- 1 = recadrage",
        "- 2 = orientation",
        "- 3 = déblocage fort",
        "- 4 = possible escalade",
        "",
        "Contexte critique :",
        `- escalationGate: ${escalationGate}`,
        `- mode attendu : ${desiredMode}`,
        "",
        "Retour JSON strict :",
        "{\"message\":\"...\",\"hintLevel\":\"low|medium|high\",\"nextAction\":\"...\",\"confidence\":0.0,\"responseMode\":\"reframe|guide|unstick|escalate\",\"shouldEscalate\":false,\"reasonTag\":\"...\"}"
      ].join("\n");

      const userPrompt = JSON.stringify(
        {
          session: payload,
          recentAiHelps: recentSummary,
          instruction:
            "Réponds sans répétition et sans langage technique. Si l’aide humaine n’est pas encore ouverte, n’oriente pas vers elle.",
        },
        null,
        2
      );

      let structured;
      let model = "gpt-5.4-mini";

      try {
        const response = await openai.responses.create({
          model,
          input: [
            {
              role: "system",
              content: [{ type: "input_text", text: systemPrompt }],
            },
            {
              role: "user",
              content: [{ type: "input_text", text: userPrompt }],
            },
          ],
        });

        const rawText = extractOutputText(response);
        structured = parseStructuredJson(rawText, payload, recentLogs);

        if (payload.humanHelpEnabled && payload.aiHelpCount + 1 < 4) {
          structured.shouldEscalate = false;
          if (structured.responseMode === "escalate") {
            structured.responseMode = "unstick";
          }
          if (structured.reasonTag === "human_relay") {
            structured.reasonTag = "severe_block";
          }
        }
      } catch (error) {
        console.error("OpenAI call failed:", error);
        structured = fallbackHelp(payload, recentLogs);
        model = "fallback_local";
      }

      const logDoc = {
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        source: "ai_function",
        model,
        sessionId: payload.sessionId,
        request: payload,
        response: structured,
      };

      await firestore
        .collection("gameSessions")
        .doc(payload.sessionId)
        .collection("aiHelpLogs")
        .add(logDoc);

      await firestore
        .collection("gameSessions")
        .doc(payload.sessionId)
        .collection("timeline")
        .add({
          type: structured.shouldEscalate
            ? "player_ai_help_escalation_ready"
            : "player_ai_help_generated",
          createdAt: new Date().toISOString(),
          label: `Aide Grid générée (${structured.hintLevel} / ${structured.responseMode})`,
          source: "ai",
          placeId: payload.place.id || null,
          placeName: payload.place.name || null,
          reasonTag: structured.reasonTag,
        });

      return res.status(200).json({
        ok: true,
        data: structured,
      });
    } catch (error) {
      console.error("getStructuredAiHelp failed:", error);
      return res.status(500).json({
        ok: false,
        error: error?.message || "Internal server error.",
      });
    }
  }
);
// AJOUT EN BAS DU FICHIER

exports.markCodeAsUsed = onCall(async (request) => {
  const { sessionId } = request.data || {};

  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId requis.");
  }

  const sessionRef = firestore.collection("gameSessions").doc(sessionId);

  await firestore.runTransaction(async (tx) => {
    const sessionSnap = await tx.get(sessionRef);

    if (!sessionSnap.exists) {
      throw new HttpsError("not-found", "Session introuvable.");
    }

    const session = sessionSnap.data() || {};

    const batchId = session.activationBatchId;
    const code = session.activationCode;

    if (!batchId || !code) {
      throw new HttpsError("failed-precondition", "Données d’activation manquantes.");
    }

    const codeRef = firestore
      .collection("activationBatches")
      .doc(batchId)
      .collection("codes")
      .doc(code);

    const batchRef = firestore.collection("activationBatches").doc(batchId);

    const codeSnap = await tx.get(codeRef);
    const batchSnap = await tx.get(batchRef);

    if (!codeSnap.exists) {
      throw new HttpsError("not-found", "Code introuvable.");
    }

    const codeData = codeSnap.data() || {};
    const batchData = batchSnap.data() || {};

    // Si déjà used → on ne refait rien
    if (codeData.status === "used") {
      return;
    }

    tx.update(codeRef, {
      status: "used",
      usedAt: new Date().toISOString(),
      usedBySessionId: sessionId,
    });

    tx.update(batchRef, {
      countReserved: Math.max(0, (batchData.countReserved || 0) - 1),
      countUsed: (batchData.countUsed || 0) + 1,
    });
  });

  return { success: true };
});
