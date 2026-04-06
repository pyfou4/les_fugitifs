import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/portal_access_service.dart';

class AdminEmployeesSection extends StatefulWidget {
  final PortalAccessProfile currentProfile;

  const AdminEmployeesSection({
    super.key,
    required this.currentProfile,
  });

  @override
  State<AdminEmployeesSection> createState() => _AdminEmployeesSectionState();
}

class _AdminEmployeesSectionState extends State<AdminEmployeesSection> {
  final PortalAccessService _portalAccessService = PortalAccessService();

  Future<void> _openEditor({
    QueryDocumentSnapshot<Map<String, dynamic>>? doc,
  }) async {
    final data = doc?.data() ?? <String, dynamic>{};

    final uidCtrl = TextEditingController(text: (data['uid'] ?? doc?.id ?? '').toString());
    final emailCtrl = TextEditingController(text: (data['email'] ?? '').toString());
    final displayNameCtrl = TextEditingController(text: (data['displayName'] ?? '').toString());

    PortalUserRole selectedRole = PortalAccessService.parseRoleValue(
          (data['role'] ?? '').toString(),
        ) ??
        PortalUserRole.caissier;

    bool isActive = (data['isActive'] ?? true) == true;
    String? errorText;
    bool isSaving = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF151B25),
              title: Text(
                doc == null ? 'Ajouter un accès portail' : 'Modifier l’accès portail',
                style: const TextStyle(color: Colors.white),
              ),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Important: le compte Firebase Auth doit déjà exister. Ici, tu gères le rôle portail associé au uid.',
                          style: TextStyle(
                            color: Color(0xFFB8C3D6),
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: uidCtrl,
                        enabled: !isSaving && doc == null,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'UID Firebase Auth',
                          helperText: 'Utilise exactement l’ID utilisateur visible dans Firebase Authentication.',
                          errorText: errorText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailCtrl,
                        enabled: !isSaving,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Email',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: displayNameCtrl,
                        enabled: !isSaving,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nom affiché',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<PortalUserRole>(
                        value: selectedRole,
                        dropdownColor: const Color(0xFF171E2A),
                        decoration: const InputDecoration(
                          labelText: 'Rôle',
                        ),
                        items: PortalUserRole.values
                            .map(
                              (role) => DropdownMenuItem(
                                value: role,
                                child: Text(role.label),
                              ),
                            )
                            .toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setLocalState(() {
                                  selectedRole = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: isActive,
                        onChanged: isSaving
                            ? null
                            : (value) {
                                setLocalState(() {
                                  isActive = value;
                                });
                              },
                        title: const Text(
                          'Compte actif',
                          style: TextStyle(color: Colors.white),
                        ),
                        subtitle: const Text(
                          'Si désactivé, la connexion reste possible côté Auth mais l’accès portail sera refusé.',
                          style: TextStyle(color: Color(0xFF9AA7BC)),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final uid = uidCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final displayName = displayNameCtrl.text.trim();

                          if (uid.isEmpty || email.isEmpty || displayName.isEmpty) {
                            setLocalState(() {
                              errorText = 'UID, email et nom affiché obligatoires.';
                            });
                            return;
                          }

                          setLocalState(() {
                            isSaving = true;
                            errorText = null;
                          });

                          Navigator.of(context).pop({
                            'uid': uid,
                            'email': email,
                            'displayName': displayName,
                            'role': selectedRole,
                            'isActive': isActive,
                          });
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD65A00),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Sauvegarder'),
                ),
              ],
            );
          },
        );
      },
    );

    uidCtrl.dispose();
    emailCtrl.dispose();
    displayNameCtrl.dispose();

    if (result == null) return;

    try {
      await _portalAccessService.upsertPortalUser(
        uid: result['uid'] as String,
        email: result['email'] as String,
        displayName: result['displayName'] as String,
        role: result['role'] as PortalUserRole,
        isActive: result['isActive'] as bool,
        updatedBy: widget.currentProfile.uid,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            doc == null
                ? 'Accès portail créé.'
                : 'Accès portail mis à jour.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur pendant la sauvegarde du rôle : $e'),
        ),
      );
    }
  }

  Future<void> _toggleActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool nextValue,
  ) async {
    final data = doc.data();
    await _portalAccessService.upsertPortalUser(
      uid: (data['uid'] ?? doc.id).toString(),
      email: (data['email'] ?? '').toString(),
      displayName: (data['displayName'] ?? '').toString(),
      role: PortalAccessService.parseRoleValue((data['role'] ?? '').toString()) ??
          PortalUserRole.caissier,
      isActive: nextValue,
      updatedBy: widget.currentProfile.uid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(nextValue ? 'Accès activé.' : 'Accès désactivé.'),
      ),
    );
  }

  Color _roleColor(PortalUserRole role) {
    switch (role) {
      case PortalUserRole.admin:
        return const Color(0xFFFFB24A);
      case PortalUserRole.scenariste:
        return const Color(0xFF6C7CFF);
      case PortalUserRole.caissier:
        return const Color(0xFF68E36B);
      case PortalUserRole.maitreJeu:
        return const Color(0xFFE56AF7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF131A24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('portalUsers')
              .orderBy('displayName')
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Employés & rôles portail',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Attribue un rôle portail à un compte Firebase Auth existant. Admin voit tout, puis la hiérarchie se resserre vers scénariste, caisse et MJ.',
                            style: TextStyle(
                              color: Color(0xFF9AA7BC),
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.icon(
                      onPressed: () => _openEditor(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFD65A00),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Ajouter un accès'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (docs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E1724),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF233041)),
                    ),
                    child: const Text(
                      'Aucun accès portail pour l’instant. Crée d’abord un utilisateur dans Firebase Authentication, puis ajoute ici son UID.',
                      style: TextStyle(
                        color: Color(0xFFB8C3D6),
                        height: 1.45,
                      ),
                    ),
                  )
                else
                  Column(
                    children: docs.map((doc) {
                      final data = doc.data();
                      final role = PortalAccessService.parseRoleValue(
                            (data['role'] ?? '').toString(),
                          ) ??
                          PortalUserRole.caissier;
                      final isActive = (data['isActive'] ?? true) == true;
                      final displayName =
                          (data['displayName'] ?? 'Sans nom').toString();
                      final email = (data['email'] ?? '').toString();
                      final uid = (data['uid'] ?? doc.id).toString();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1724),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF233041)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _roleColor(role).withOpacity(0.18),
                              child: Icon(
                                Icons.badge_outlined,
                                color: _roleColor(role),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _roleColor(role).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: _roleColor(role).withOpacity(0.45),
                                          ),
                                        ),
                                        child: Text(
                                          role.label,
                                          style: TextStyle(
                                            color: _roleColor(role),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? const Color(0xFF68E36B).withOpacity(0.12)
                                              : const Color(0xFFFF6B6B).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: isActive
                                                ? const Color(0xFF68E36B).withOpacity(0.45)
                                                : const Color(0xFFFF6B6B).withOpacity(0.45),
                                          ),
                                        ),
                                        child: Text(
                                          isActive ? 'Actif' : 'Désactivé',
                                          style: TextStyle(
                                            color: isActive
                                                ? const Color(0xFF68E36B)
                                                : const Color(0xFFFF6B6B),
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    email,
                                    style: const TextStyle(
                                      color: Color(0xFFAED0FF),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    'UID: $uid',
                                    style: const TextStyle(
                                      color: Color(0xFF8EA4C7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Switch(
                                  value: isActive,
                                  onChanged: (value) => _toggleActive(doc, value),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openEditor(doc: doc),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Modifier'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
