import 'package:flutter/material.dart';

import '../services/portal_access_service.dart';
import '../widgets/header_brand.dart';
import 'admin_screen.dart';
import 'cashier_screen.dart';
import 'creator_screen.dart';
import 'master_game_screen.dart';

class PortalShellScreen extends StatefulWidget {
  final PortalAccessProfile profile;

  const PortalShellScreen({
    super.key,
    required this.profile,
  });

  @override
  State<PortalShellScreen> createState() => _PortalShellScreenState();
}

class _PortalShellScreenState extends State<PortalShellScreen> {
  final PortalAccessService _portalAccessService = PortalAccessService();
  late final List<_PortalDestination> _destinations;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _destinations = _buildDestinations(widget.profile);
  }

  List<_PortalDestination> _buildDestinations(PortalAccessProfile profile) {
    final role = profile.role;
    final destinations = <_PortalDestination>[];

    if (role.canAccessAdmin) {
      destinations.add(
        _PortalDestination(
          key: 'admin',
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          builder: () => AdminScreen(profile: profile),
        ),
      );
    }

    if (role.canAccessCreator) {
      destinations.add(
        _PortalDestination(
          key: 'creator',
          label: 'Scénariste',
          icon: Icons.auto_stories_outlined,
          builder: () => CreatorScreen(profile: profile),
        ),
      );
    }

    if (role.canAccessCashier) {
      destinations.add(
        _PortalDestination(
          key: 'cashier',
          label: 'Caisse',
          icon: Icons.confirmation_number_outlined,
          builder: () => CashierScreen(profile: profile),
        ),
      );
    }

    if (role.canAccessMasterGame) {
      destinations.add(
        _PortalDestination(
          key: 'mj',
          label: 'MJ',
          icon: Icons.support_agent_outlined,
          builder: () => MasterGameScreen(profile: profile),
        ),
      );
    }

    return destinations;
  }

  Future<void> _signOut() async {
    await _portalAccessService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final destination = _destinations[_selectedIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF0F141D),
            extended: true,
            selectedIndex: _selectedIndex,
            leading: const Padding(
              padding: EdgeInsets.only(top: 16, bottom: 8),
              child: HeaderBrand(),
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFD65A00),
                    child: Text(
                      widget.profile.displayName.isEmpty
                          ? '?'
                          : widget.profile.displayName.characters.first
                              .toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.profile.displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFFD7B8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.profile.role.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFAAB7C8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 14),
                  IconButton(
                    onPressed: _signOut,
                    tooltip: 'Se déconnecter',
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),
            destinations: _destinations
                .map(
                  (entry) => NavigationRailDestination(
                    icon: Icon(entry.icon),
                    selectedIcon: Icon(entry.icon),
                    label: Text(entry.label),
                  ),
                )
                .toList(),
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 18,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0A1220),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF1C2A3E)),
                    ),
                  ),
                  child: Text(
                    destination.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Expanded(
                  child: destination.builder(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalDestination {
  final String key;
  final String label;
  final IconData icon;
  final Widget Function() builder;

  _PortalDestination({
    required this.key,
    required this.label,
    required this.icon,
    required this.builder,
  });
}
