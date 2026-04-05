import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _sessionActiveKey = 'session_active';
  static const _sessionExpiresAtKey = 'session_expires_at';
  static const _activeGameSessionIdKey = 'active_game_session_id';
  static const _gameSessionIdKey = 'game_session_id';
  static const _activeActivationCodeKey = 'active_activation_code';
  static const _activationCodeKey = 'activation_code';
  static const _sessionDeviceIdKey = 'session_device_id';

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Récupère un identifiant d'appareil stable pour autoriser
  /// la reprise de session sur le même appareil.
  static Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id.isNotEmpty
          ? androidInfo.id
          : (androidInfo.device.isNotEmpty
              ? androidInfo.device
              : 'unknown_android');
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    }

    return 'unknown_device';
  }

  static String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static bool _isAllowedStatus(String status) {
    return status == 'active' || status == 'started';
  }

  /// Vérifie si une session locale est active ET encore valide.
  /// Si un id de session est stocké, on recroise aussi avec Firestore.
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();

    final isActive = prefs.getBool(_sessionActiveKey) ?? false;
    final expiresAtString = prefs.getString(_sessionExpiresAtKey);

    if (!isActive || expiresAtString == null || expiresAtString.trim().isEmpty) {
      return false;
    }

    final expiresAt = DateTime.tryParse(expiresAtString);
    final now = DateTime.now();

    if (expiresAt == null || !now.isBefore(expiresAt)) {
      return false;
    }

    final sessionId = _firstNonEmpty([
      prefs.getString(_activeGameSessionIdKey),
      prefs.getString(_gameSessionIdKey),
    ]);
    final activationCode = _firstNonEmpty([
      prefs.getString(_activeActivationCodeKey),
      prefs.getString(_activationCodeKey),
    ]);

    if (sessionId == null && activationCode == null) {
      return false;
    }

    try {
      DocumentSnapshot<Map<String, dynamic>>? sessionDoc;

      if (sessionId != null) {
        final doc = await _firestore.collection('gameSessions').doc(sessionId).get();
        if (!doc.exists) return false;
        sessionDoc = doc;
      } else {
        final query = await _firestore
            .collection('gameSessions')
            .where('activationCode', isEqualTo: activationCode)
            .limit(1)
            .get();

        if (query.docs.isEmpty) return false;
        sessionDoc = query.docs.first;
      }

      final data = sessionDoc.data();
      if (data == null) return false;

      final status = (data['status'] ?? '').toString().trim();
      if (!_isAllowedStatus(status)) {
        return false;
      }

      final remoteExpiresAtString = (data['expiresAt'] ?? '').toString().trim();
      final remoteExpiresAt = remoteExpiresAtString.isEmpty
          ? null
          : DateTime.tryParse(remoteExpiresAtString);

      if (remoteExpiresAt != null && !now.isBefore(remoteExpiresAt)) {
        return false;
      }

      final localDeviceId = prefs.getString(_sessionDeviceIdKey);
      final remoteUsedByDeviceId = (data['usedByDeviceId'] ?? '').toString().trim();

      if (localDeviceId != null &&
          localDeviceId.isNotEmpty &&
          remoteUsedByDeviceId.isNotEmpty &&
          remoteUsedByDeviceId != localDeviceId) {
        return false;
      }

      final code = (data['activationCode'] ?? activationCode ?? '').toString().trim();

      await prefs.setBool(_sessionActiveKey, true);
      await prefs.setString(
        _sessionExpiresAtKey,
        remoteExpiresAtString.isNotEmpty ? remoteExpiresAtString : expiresAtString,
      );
      await prefs.setString(_activeGameSessionIdKey, sessionDoc.id);
      await prefs.setString(_gameSessionIdKey, sessionDoc.id);
      if (code.isNotEmpty) {
        await prefs.setString(_activeActivationCodeKey, code);
        await prefs.setString(_activationCodeKey, code);
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Active une session avec un code.
  ///
  /// Nouvelle architecture:
  /// - cherche une vraie gameSession par activationCode
  /// - vérifie statut + expiration
  /// - rattache l'appareil si nécessaire
  /// - autorise la reprise sur le même appareil
  static Future<bool> activateCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final deviceId = await _getDeviceId();

    try {
      final query = await _firestore
          .collection('gameSessions')
          .where('activationCode', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return false;
      }

      final sessionDoc = query.docs.first;
      final data = sessionDoc.data();

      final status = (data['status'] ?? '').toString().trim();
      if (!_isAllowedStatus(status)) {
        return false;
      }

      final expiresAtString = (data['expiresAt'] ?? '').toString().trim();
      if (expiresAtString.isEmpty) {
        return false;
      }

      final expiresAt = DateTime.tryParse(expiresAtString);
      if (expiresAt == null || expiresAt.isBefore(DateTime.now())) {
        return false;
      }

      final remoteUsedByDeviceId = (data['usedByDeviceId'] ?? '').toString().trim();

      if (remoteUsedByDeviceId.isNotEmpty && remoteUsedByDeviceId != deviceId) {
        return false;
      }

      final shouldAttachDevice = remoteUsedByDeviceId.isEmpty;

      if (shouldAttachDevice) {
        await sessionDoc.reference.set({
          'usedByDeviceId': deviceId,
          'activatedAt': DateTime.now().toIso8601String(),
        }, SetOptions(merge: true));
      }

      await prefs.setBool(_sessionActiveKey, true);
      await prefs.setString(_sessionExpiresAtKey, expiresAtString);
      await prefs.setString(_activeGameSessionIdKey, sessionDoc.id);
      await prefs.setString(_gameSessionIdKey, sessionDoc.id);
      await prefs.setString(_activeActivationCodeKey, code);
      await prefs.setString(_activationCodeKey, code);
      await prefs.setString(_sessionDeviceIdKey, deviceId);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reset session locale.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionActiveKey);
    await prefs.remove(_sessionExpiresAtKey);
    await prefs.remove(_activeGameSessionIdKey);
    await prefs.remove(_gameSessionIdKey);
    await prefs.remove(_activeActivationCodeKey);
    await prefs.remove(_activationCodeKey);
    await prefs.remove(_sessionDeviceIdKey);
  }
}
