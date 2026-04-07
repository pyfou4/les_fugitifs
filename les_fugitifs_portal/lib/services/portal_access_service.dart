import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum PortalUserRole {
  admin,
  scenariste,
  caissier,
  maitreJeu,
}

extension PortalUserRoleX on PortalUserRole {
  String get firestoreValue {
    switch (this) {
      case PortalUserRole.admin:
        return 'admin';
      case PortalUserRole.scenariste:
        return 'scenariste';
      case PortalUserRole.caissier:
        return 'caissier';
      case PortalUserRole.maitreJeu:
        return 'maitre_jeu';
    }
  }

  String get label {
    switch (this) {
      case PortalUserRole.admin:
        return 'Admin';
      case PortalUserRole.scenariste:
        return 'Scénariste';
      case PortalUserRole.caissier:
        return 'Caissier';
      case PortalUserRole.maitreJeu:
        return 'Maître de jeu';
    }
  }

  bool get canAccessAdmin => this == PortalUserRole.admin;

  bool get canAccessCreator =>
      this == PortalUserRole.admin || this == PortalUserRole.scenariste;

  bool get canAccessCashier =>
      this == PortalUserRole.admin ||
      this == PortalUserRole.scenariste ||
      this == PortalUserRole.caissier;

  bool get canAccessMasterGame => true;
}

class PortalAccessProfile {
  final String uid;
  final String email;
  final String displayName;
  final PortalUserRole role;
  final bool isActive;
  final bool mustChangePassword;

  const PortalAccessProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.mustChangePassword = false,
  });
}

class PortalAccessService {
  PortalAccessService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<PortalAccessProfile?> readCurrentProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final snap = await _firestore.collection('portalUsers').doc(user.uid).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? <String, dynamic>{};
    final role = parseRoleValue((data['role'] ?? '').toString().trim());
    if (role == null) return null;

    return PortalAccessProfile(
      uid: user.uid,
      email: (data['email'] ?? user.email ?? '').toString().trim(),
      displayName: (data['displayName'] ?? user.displayName ?? user.email ?? '')
          .toString()
          .trim(),
      role: role,
      isActive: (data['isActive'] ?? true) == true,
      mustChangePassword: _readMustChangePassword(data),
    );
  }

  Future<void> updateCurrentPasswordAndClearFirstAccess({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté.');
    }

    final email = (user.email ?? '').trim();
    if (email.isEmpty) {
      throw Exception('Impossible de réauthentifier ce compte sans email.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);

    await _firestore.collection('portalUsers').doc(user.uid).set({
      'mustChangePassword': false,
      'passwordChangedAt': DateTime.now().toUtc().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> upsertPortalUser({
    required String uid,
    required String email,
    required String displayName,
    required PortalUserRole role,
    required bool isActive,
    required String updatedBy,
    bool mustChangePassword = false,
  }) async {
    await _firestore.collection('portalUsers').doc(uid).set({
      'uid': uid,
      'email': email.trim(),
      'displayName': displayName.trim(),
      'role': role.firestoreValue,
      'isActive': isActive,
      'mustChangePassword': mustChangePassword,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
  }

  static PortalUserRole? parseRoleValue(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'admin':
        return PortalUserRole.admin;
      case 'scenariste':
        return PortalUserRole.scenariste;
      case 'caissier':
        return PortalUserRole.caissier;
      case 'maitre_jeu':
      case 'maitrejeu':
      case 'mj':
        return PortalUserRole.maitreJeu;
      default:
        return null;
    }
  }

  static bool _readMustChangePassword(Map<String, dynamic> data) {
    final candidates = [
      data['mustChangePassword'],
      data['forcePasswordChange'],
      data['requirePasswordChange'],
      data['firstLoginPasswordResetRequired'],
    ];

    for (final value in candidates) {
      if (value is bool) return value;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      if (value is num) return value != 0;
    }

    return false;
  }
}
