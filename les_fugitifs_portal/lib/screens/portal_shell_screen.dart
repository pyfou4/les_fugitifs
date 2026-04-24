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
          _PortalSidebar(
            isCollapsed: isSidebarCollapsed,
            destinations: _destinations,
            selectedIndex: _selectedIndex,
            profile: widget.profile,
            onToggle: () => _toggleSidebar(isSidebarCollapsed),
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            onSignOut: _signOut,
          ),
          Container(
            width: 1,
            color: const Color(0xFF243043),
          ),
          Expanded(
            child: destination.builder(),
          ),
        ],
      ),
    );
  }
}

class _PortalSidebar extends StatelessWidget {
  final bool isCollapsed;
  final List<_PortalDestination> destinations;
  final int selectedIndex;
  final PortalAccessProfile profile;
  final VoidCallback onToggle;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSignOut;

  const _PortalSidebar({
    required this.isCollapsed,
    required this.destinations,
    required this.selectedIndex,
    required this.profile,
    required this.onToggle,
    required this.onDestinationSelected,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 90 : 264,
      color: const Color(0xFF0F141D),
      child: SafeArea(
        child: Column(
          children: [
            _PortalSidebarHeader(
              isCollapsed: isCollapsed,
              onToggle: onToggle,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(
                  horizontal: isCollapsed ? 6 : 12,
                  vertical: 4,
                ),
                itemCount: destinations.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final isSelected = index == selectedIndex;

                  return _PortalSidebarItem(
                    isCollapsed: isCollapsed,
                    isSelected: isSelected,
                    label: destination.label,
                    icon: destination.icon,
                    onTap: () => onDestinationSelected(index),
                  );
                },
              ),
            ),
            _PortalSidebarFooter(
              isCollapsed: isCollapsed,
              profile: profile,
              onSignOut: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalSidebarHeader extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _PortalSidebarHeader({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
        child: Column(
          children: [
            _PortalIconButton(
              icon: Icons.chevron_right,
              tooltip: 'Ouvrir le menu',
              onPressed: onToggle,
            ),
            const SizedBox(height: 12),
            const Icon(
              Icons.account_tree_outlined,
              color: Color(0xFFD65A00),
              size: 28,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeaderBrand(),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: _PortalWideToggleButton(
              onPressed: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalSidebarItem extends StatelessWidget {
  final bool isCollapsed;
  final bool isSelected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PortalSidebarItem({
    required this.isCollapsed,
    required this.isSelected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        isSelected ? const Color(0xFF7B513A) : Colors.transparent;
    final foregroundColor = isSelected ? Colors.white : const Color(0xFFEADFD8);

    final item = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 48,
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 0 : 14,
          ),
          child: Row(
            mainAxisAlignment:
                isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: foregroundColor,
                size: 24,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: TextStyle(
                      color: foregroundColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isCollapsed) {
      return Tooltip(
        message: label,
        child: item,
      );
    }

    return item;
  }
}

class _PortalWideToggleButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _PortalWideToggleButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left,
                color: Colors.white,
                size: 22,
              ),
              SizedBox(width: 6),
              Text(
                'Réduire',
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

class _PortalIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _PortalIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFD65A00),
        elevation: 6,
        shadowColor: const Color(0x66000000),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalSidebarFooter extends StatelessWidget {
  final bool isCollapsed;
  final PortalAccessProfile profile;
  final VoidCallback onSignOut;

  const _PortalSidebarFooter({
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
      padding: EdgeInsets.fromLTRB(
        isCollapsed ? 6 : 12,
        10,
        isCollapsed ? 6 : 12,
        18,
      ),
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
            Text(
              profile.displayName,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(
                color: Color(0xFFFFD7B8),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              profile.role.label,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Color(0xFFAAB7C8),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Tooltip(
            message: 'Se déconnecter',
            child: IconButton(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout),
              color: const Color(0xFFEADFD8),
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
