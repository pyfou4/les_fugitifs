import 'package:cloud_functions/cloud_functions.dart';

import 'portal_access_service.dart';

class PortalEmployeeAdminService {
  PortalEmployeeAdminService({
    FirebaseFunctions? functions,
  }) : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<void> createPortalEmployee({
    required String email,
    required String displayName,
    required String password,
    required PortalUserRole role,
    required bool isActive,
  }) async {
    final callable = _functions.httpsCallable('createPortalEmployee');

    await callable.call({
      'email': email.trim(),
      'displayName': displayName.trim(),
      'password': password,
      'role': role.firestoreValue,
      'isActive': isActive,
    });
  }
}
