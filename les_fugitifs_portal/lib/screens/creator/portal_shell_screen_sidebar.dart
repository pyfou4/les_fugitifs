import 'dart:html' as html;

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
  static const String _sidebarCollapsedPreferenceKey =
      'les_fugitifs_portal_sidebar_collapsed';

  final PortalAccessService _portalAccessService = PortalAccessService();
  late final List<_PortalDestination> _destinations;
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  bool _hasStoredSidebarPreference = false;

  @override
  void initState() {
    super.initState();
    _destinations = _buildDestinations(widget.profile);
    _restoreSidebarPreference();
  }

  void _restoreSidebarPreference() {
    final storedValue = html.window.localStorage[_sidebarCollapsedPreferenceKey];

    if (storedValue == null) {
      _hasStoredSidebarPreference = false;
      return;
    }

    _hasStoredSidebarPreference = true;
    _isSidebarCollapsed = storedValue == 'true';
  }

  void _toggleSidebar(bool currentValue) {
    final nextValue = !currentValue;

    setState(() {
      _isSidebarCollapsed = nextValue;
      _hasStoredSidebarPreference = true;
    });

    html.window.localStorage[_sidebarCollapsedPreferenceKey] =
        nextValue.toString();
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final shouldCollapseByDefault = screenWidth < 900;
    final isSidebarCollapsed = _hasStoredSidebarPreference
        ? _isSidebarCollapsed
        : shouldCollapseByDefault;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF0F141D),
            extended: !isSidebarCollapsed,
            minWidth: 72,
            minExtendedWidth: 220,
            selectedIndex: _selectedIndex,
            labelType: NavigationRailLabelType.none,
            leading: _PortalRailHeader(
              isCollapsed: isSidebarCollapsed,
              onToggle: () => _toggleSidebar(isSidebarCollapsed),
            ),
            trailing: _PortalRailFooter(
              isCollapsed: isSidebarCollapsed,
              profile: widget.profile,
              onSignOut: _signOut,
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
            child: destination.builder(),
          ),
        ],
      ),
    );
  }
}

class _PortalRailHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _PortalRailHeader({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 12),
        child: Column(
          children: [
            _PortalSidebarToggleButton(
              isCollapsed: true,
              onPressed: onToggle,
            ),
            const SizedBox(height: 12),
            const Icon(
              Icons.account_tree_outlined,
              color: Color(0xFFD65A00),
              size: 26,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeaderBrand(),
          const SizedBox(height: 12),
          _PortalSidebarToggleButton(
            isCollapsed: false,
            onPressed: onToggle,
          ),
        ],
      ),
    );
  }
}

class _PortalSidebarToggleButton extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onPressed;

  const _PortalSidebarToggleButton({
    required this.isCollapsed,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Material(
        color: const Color(0xFFD65A00),
        elevation: 6,
        shadowColor: const Color(0x66000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: const SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      );
    }

    return Material(
      color: const Color(0xFFD65A00),
      elevation: 6,
      shadowColor: const Color(0x66000000),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 6),
              Text(
                'Réduire le menu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalRailFooter extends StatelessWidget {
  final bool isCollapsed;
  final PortalAccessProfile profile;
  final VoidCallback onSignOut;

  const _PortalRailFooter({
    required this.isCollapsed,
    required this.profile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.isEmpty
        ? '?'
        : profile.displayName.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: isCollapsed ? 18 : 20,
            backgroundColor: const Color(0xFFD65A00),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                profile.displayName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFFFFD7B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                profile.role.label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  color: Color(0xFFAAB7C8),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          IconButton(
            onPressed: onSignOut,
            tooltip: 'Se déconnecter',
            icon: const Icon(Icons.logout),
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
