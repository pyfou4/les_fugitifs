import 'package:cloud_firestore/cloud_firestore.dart';

import 'site_readiness_models.dart';
import 'site_readiness_validator.dart';

class SiteReadinessService {
  SiteReadinessService({
    FirebaseFirestore? firestore,
    SiteReadinessValidator? validator,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _validator = validator ?? const SiteReadinessValidator();

  final FirebaseFirestore _firestore;
  final SiteReadinessValidator _validator;

  DocumentReference<Map<String, dynamic>> _siteRef(String siteId) =>
      _firestore.collection('sites').doc(siteId);

  CollectionReference<Map<String, dynamic>> _sitePlacesRef(String siteId) =>
      _siteRef(siteId).collection('places');

  CollectionReference<Map<String, dynamic>> get _placeTemplatesRef =>
      _firestore
          .collection('games')
          .doc('les_fugitifs')
          .collection('placeTemplates');

  Future<SiteReadinessResult> validateSite(String siteId) async {
    final siteSnap = await _siteRef(siteId).get();
    final templateSnap = await _placeTemplatesRef.get();
    final sitePlacesSnap = await _sitePlacesRef(siteId).get();

    return _validator.validate(
      siteId: siteId,
      siteData: siteSnap.data(),
      templateDocsById: {
        for (final doc in templateSnap.docs) doc.id: doc.data(),
      },
      sitePlacesById: {
        for (final doc in sitePlacesSnap.docs) doc.id: doc.data(),
      },
    );
  }
}
