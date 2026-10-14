import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n.dart';
import '../features/auth/domain/user.dart';
import '../features/notifications/presentation/notifications_screen.dart';

class _Destination {
  const _Destination(
    this.icon,
    this.selectedIcon,
    this.label, {
    this.badge = false,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool badge;
}

/// Bottom-navigation shell per role. Uses a navigation rail on wide screens.
class RoleShell extends ConsumerWidget {
  const RoleShell({super.key, required this.shell, required this.role});

  final StatefulNavigationShell shell;
  final UserRole role;

  List<_Destination> _destinations(AppLocalizations l) => switch (role) {
    UserRole.student => [
      _Destination(Icons.explore_outlined, Icons.explore_rounded, l.navBrowse),
      _Destination(
        Icons.search_rounded,
        Icons.saved_search_rounded,
        l.navSearch,
      ),
      _Destination(
        Icons.favorite_border_rounded,
        Icons.favorite_rounded,
        l.navFavorites,
      ),
      _Destination(
        Icons.notifications_none_rounded,
        Icons.notifications_rounded,
        l.navNotifications,
        badge: true,
      ),
      _Destination(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        l.navProfile,
      ),
    ],
    UserRole.library => [
      _Destination(
        Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded,
        l.navDashboard,
      ),
      _Destination(
        Icons.folder_open_outlined,
        Icons.folder_rounded,
        l.navContent,
      ),
      _Destination(
        Icons.notifications_none_rounded,
        Icons.notifications_rounded,
        l.navNotifications,
        badge: true,
      ),
      _Destination(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        l.navProfile,
      ),
    ],
    UserRole.admin => [
      _Destination(
        Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded,
        l.navDashboard,
      ),
      _Destination(Icons.group_outlined, Icons.group_rounded, l.navUsers),
      _Destination(
        Icons.account_tree_outlined,
        Icons.account_tree_rounded,
        l.navStructure,
      ),
      _Destination(
        Icons.devices_other_outlined,
        Icons.devices_other_rounded,
        l.navDevices,
      ),
      _Destination(Icons.grid_view_outlined, Icons.grid_view_rounded, l.more),
    ],
  };

  void _go(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destinations = _destinations(context.l10n);
    final unread = ref.watch(unreadNotificationsProvider);
    Widget icon(_Destination d, {required bool selected}) {
      final i = Icon(selected ? d.selectedIcon : d.icon);
      return d.badge && unread > 0
          ? Badge(label: Text(unread > 9 ? '9+' : '$unread'), child: i)
          : i;
    }

    final wide = MediaQuery.sizeOf(context).width >= 840;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: _go,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: icon(d, selected: false),
                    selectedIcon: icon(d, selected: true),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: icon(d, selected: false),
              selectedIcon: icon(d, selected: true),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
