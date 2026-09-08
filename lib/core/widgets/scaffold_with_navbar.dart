import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';

/// Base shell layout wrapping all authenticated screens.
///
/// Renders a [NavigationBar] (Material 3) at the bottom with three destinations:
/// Ledger, Friends, and Settings. The active index is derived from the current
/// GoRouter location so that deep-links and back-navigation stay in sync.
///
/// [child] is injected by the [ShellRoute] in [appRouterProvider] — it renders
/// whichever sub-route is currently active.
class ScaffoldWithNavbar extends StatelessWidget {
  const ScaffoldWithNavbar({super.key, required this.child});

  final Widget child;

  // Ordered to match [_destinations] index positions.
  static const List<String> _tabs = [
    AppRoutes.ledger,
    AppRoutes.friends,
    AppRoutes.settings,
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      selectedIcon: Icon(Icons.receipt_long),
      label: 'Ledger',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Friends',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  /// Derives the current [NavigationBar] index from the router location.
  int _locationToIndex(String location) {
    final idx = _tabs.indexWhere((tab) => location.startsWith(tab));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) =>
            context.go(_tabs[index]),
        destinations: _destinations,
        animationDuration: const Duration(milliseconds: 300),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),
    );
  }
}
