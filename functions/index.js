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
