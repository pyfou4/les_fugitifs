const admin = require("firebase-admin");
const {setGlobalOptions} = require("firebase-functions/v2");
const {onRequest} = require("firebase-functions/v2/https");

admin.initializeApp();

setGlobalOptions({
  maxInstances: 10,
  region: "europe-west1",
});

/* =========================
   ROUTE FUNCTION
========================= */

exports.computeRoute = onRequest(
  {
    cors: true,
    secrets: ["GOOGLE_ROUTES_API_KEY"],
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

      // 🔧 fallback distance directe (Haversine)
      const haversineDistance = (lat1, lon1, lat2, lon2) => {
        const R = 6371000;
        const toRad = (x) => (x * Math.PI) / 180;

        const dLat = toRad(lat2 - lat1);
        const dLon = toRad(lon2 - lon1);

        const a =
          Math.sin(dLat / 2) * Math.sin(dLat / 2) +
          Math.cos(toRad(lat1)) *
            Math.cos(toRad(lat2)) *
            Math.sin(dLon / 2) *
            Math.sin(dLon / 2);

        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return Math.round(R * c);
      };

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
        console.warn("Routes API error:", responseText);
      }

      let encodedPolyline = null;
      let distanceMeters = null;
      let duration = null;

      try {
        const data = JSON.parse(responseText);
        const routes = data.routes || [];

        if (routes.length) {
          const route = routes[0];
          encodedPolyline = route?.polyline?.encodedPolyline || null;
          distanceMeters = route?.distanceMeters ?? null;
          duration = route?.duration || null;
        }
      } catch (e) {
        console.warn("Failed to parse Routes API response");
      }

      // 🔥 FALLBACK SI DONNÉES INCOMPLÈTES
      if (!distanceMeters) {
        distanceMeters = haversineDistance(
          parsedOriginLat,
          parsedOriginLng,
          parsedDestinationLat,
          parsedDestinationLng
        );
      }

      if (!duration) {
        // approx marche 1.4 m/s
        duration = `${Math.round(distanceMeters / 1.4)}s`;
      }

      return res.status(200).json({
        distanceMeters,
        duration,
        encodedPolyline, // peut être null → Flutter gère
      });
    } catch (error) {
      return res.status(500).json({
        error: "Unexpected error while computing route.",
        details: error && error.message ? error.message : String(error),
      });
    }
  }
);