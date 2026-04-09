const admin = require("firebase-admin");
const OpenAI = require("openai");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onRequest} = require("firebase-functions/v2/https");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1",
});

const firestore = admin.firestore();

/* =========================
   SHARED HELPERS
========================= */

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
  return ["reframe", "guide", "unstick", "escalate"].includes(normalized) ?
    normalized :
    fallback;
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
    "unknown",
  ];
  return allowed.includes(normalized) ? normalized : fallback;
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

function computeResponseMode(payload) {
  const blockage = sanitizeString(
    payload.currentBlockageLevel,
    "unknown"
  ).toLowerCase();

  if (blockage === "high" && payload.aiHelpCount >= 2) {
    return payload.humanHelpEnabled ? "escalate" : "unstick";
  }

  if (payload.aiHelpCount <= 0) return "reframe";
  if (payload.aiHelpCount === 1) return "guide";
  if (payload.aiHelpCount === 2) return "unstick";

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

function fallbackHelp(payload) {
  const question = payload.playerQuestion.toLowerCase();
  const placeLabel = buildPlaceLabel(payload);
  const responseMode = computeResponseMode(payload);
  const hasBlockedPrereq = payload.blockedPrerequisites.length > 0;

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
      nextAction:
        "Termine le briefing avant de chercher une interaction de terrain.",
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
      nextAction:
        "Valide d’abord le déplacement, puis relance l’interaction sur place.",
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
      responseMode,
      shouldEscalate: responseMode === "escalate",
      reasonTag:
        responseMode === "escalate" ?
          "severe_block" :
          "missing_prerequisite",
    };
  }

  if (responseMode === "reframe") {
    return {
      message:
        `La Grid détecte une incohérence autour de ${placeLabel}. Un élément a été négligé ou mal interprété.`,
      hintLevel: "low",
      nextAction:
        "Reviens sur ce que ce lieu permet d’éliminer, pas seulement sur ce qu’il montre.",
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
      nextAction:
        "Croise ce point avec une autre piste déjà ouverte dans le dossier.",
      confidence: 0.68,
      responseMode,
      shouldEscalate: false,
      reasonTag: "needs_crosscheck",
    };
  }

  if (responseMode === "unstick") {
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
    nextAction: payload.humanHelpEnabled ?
      "Transmets ce blocage au maître du jeu." :
      "Change de zone ou d’angle avant une nouvelle demande.",
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

function parseStructuredJson(rawText, payload) {
  const fallback = fallbackHelp(payload);

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
        typeof parsed.shouldEscalate === "boolean" ?
          parsed.shouldEscalate :
          responseMode === "escalate" && payload.humanHelpEnabled,
      reasonTag: normalizeReasonTag(parsed.reasonTag, fallback.reasonTag),
    };
  } catch (error) {
    return fallback;
  }
}

/* =========================
   ROUTE FUNCTION
========================= */

exports.computeRoute = onRequest(
  {
    cors: true,
  },
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({
          error: "Method not allowed. Use POST.",
        });
      }

      const apiKey = process.env.GOOGLE_ROUTES_API_KEY;

      if (!apiKey) {
        return res.status(500).json({
          error: "Missing GOOGLE_ROUTES_API_KEY in Functions environment.",
        });
      }

      const {
        originLat,
        originLng,
        destinationLat,
        destinationLng,
      } = req.body || {};

      const coordinates = [
        originLat,
        originLng,
        destinationLat,
        destinationLng,
      ];

      const hasInvalidCoordinate = coordinates.some(
        (value) => value === null || value === undefined
      );

      if (hasInvalidCoordinate) {
        return res.status(400).json({
          error:
            "Missing required coordinates: originLat, originLng, destinationLat, destinationLng.",
        });
      }

      const parsedOriginLat = Number(originLat);
      const parsedOriginLng = Number(originLng);
      const parsedDestinationLat = Number(destinationLat);
      const parsedDestinationLng = Number(destinationLng);

      if (
        Number.isNaN(parsedOriginLat) ||
        Number.isNaN(parsedOriginLng) ||
        Number.isNaN(parsedDestinationLat) ||
        Number.isNaN(parsedDestinationLng)
      ) {
        return res.status(400).json({
          error: "Invalid coordinates provided.",
        });
      }

      const googleResponse = await fetch(
        "https://routes.googleapis.com/directions/v2:computeRoutes",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "X-Goog-Api-Key": apiKey,
            "X-Goog-FieldMask":
              "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline",
          },
          body: JSON.stringify({
            origin: {
              location: {
                latLng: {
                  latitude: parsedOriginLat,
                  longitude: parsedOriginLng,
                },
              },
            },
            destination: {
              location: {
                latLng: {
                  latitude: parsedDestinationLat,
                  longitude: parsedDestinationLng,
                },
              },
            },
            travelMode: "WALK",
            languageCode: "fr-FR",
            units: "METRIC",
          }),
        }
      );

      const responseText = await googleResponse.text();

      if (!googleResponse.ok) {
        return res.status(googleResponse.status).json({
          error: "Routes API request failed.",
          details: responseText,
        });
      }

      const data = JSON.parse(responseText);
      const routes = data.routes || [];

      if (!routes.length) {
        return res.status(404).json({
          error: "No route returned by Routes API.",
        });
      }

      const route = routes[0];
      const encodedPolyline = route?.polyline?.encodedPolyline;
      const distanceMeters = route?.distanceMeters;
      const duration = route?.duration;

      if (!encodedPolyline || distanceMeters == null || !duration) {
        return res.status(500).json({
          error: "Incomplete route returned by Routes API.",
        });
      }

      return res.status(200).json({
        distanceMeters,
        duration,
        encodedPolyline,
      });
    } catch (error) {
      return res.status(500).json({
        error: "Unexpected error while computing route.",
        details: error && error.message ? error.message : String(error),
      });
    }
  }
);

/* =========================
   AI HELP FUNCTION
========================= */

exports.getStructuredAiHelp = onRequest(
  {
    cors: true,
    timeoutSeconds: 60,
    memory: "512MiB",
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

      const openai = new OpenAI({apiKey});
      const desiredMode = computeResponseMode(payload);

      const systemPrompt = [
        "You are the Grid, an in-world assistance entity inside the detective game 'Les Fugitifs'.",
        "You are NOT a technical debugger and NOT a generic assistant.",
        "You speak in French.",
        "Your role is to reframe, guide, unstick, or escalate depending on the blockage level.",
        "Your response must stay immersive, cold, precise, and short.",
        "Never reveal the killer.",
        "Never reveal the motive.",
        "Never expose internal game logic, raw prerequisites, or node codes.",
        "Never mention backend, JSON, state machine, or technical implementation.",
        "Do not give a long explanation.",
        "Return 2 to 4 short sentences maximum for message.",
        "nextAction must be one short, concrete next move.",
        "Adapt the wording to the place type when provided:",
        "- media: reread, cross-check, reinterpret",
        "- observation: look again, notice a missing detail, compare",
        "- physical: act, test, try differently",
        "Available responseMode values: reframe, guide, unstick, escalate.",
        "Use escalate only when the block is strong and repeated.",
        "reasonTag must be one of:",
        "missing_prerequisite, misread_place, needs_crosscheck, severe_block, movement_issue, briefing_lock, human_relay, unknown.",
        "OUTPUT STRICT JSON ONLY.",
        "{\"message\":\"...\",\"hintLevel\":\"low|medium|high\",\"nextAction\":\"...\",\"confidence\":0.0,\"responseMode\":\"reframe|guide|unstick|escalate\",\"shouldEscalate\":false,\"reasonTag\":\"...\"}",
        `Preferred responseMode for this request: ${desiredMode}.`,
      ].join("\n");

      const userPrompt = JSON.stringify(payload, null, 2);

      let structured;
      let model = "gpt-5.4-mini";

      try {
        const response = await openai.responses.create({
          model,
          input: [
            {
              role: "system",
              content: [{type: "input_text", text: systemPrompt}],
            },
            {
              role: "user",
              content: [{type: "input_text", text: userPrompt}],
            },
          ],
        });

        const rawText = extractOutputText(response);
        structured = parseStructuredJson(rawText, payload);
      } catch (error) {
        console.error("OpenAI call failed:", error);
        structured = fallbackHelp(payload);
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
          type: structured.shouldEscalate ?
            "player_ai_help_escalation_ready" :
            "player_ai_help_generated",
          createdAt: new Date().toISOString(),
          label:
            `Aide Grid générée (${structured.hintLevel} / ${structured.responseMode})`,
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
        error: error && error.message ?
          error.message :
          "Internal server error.",
      });
    }
  }
);