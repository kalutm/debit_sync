import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../widgets/scaffold_with_navbar.dart';

// ── Route name constants ───────────────────────────────────────────────────────

/// Named route constants to avoid magic strings at call sites.
abstract final class AppRoutes {
  static const String login    = '/login';
  static const String home     = '/home';
  static const String ledger   = '/ledger';
  static const String friends  = '/friends';
  static const String settings = '/settings';
}

// ── Router Provider ────────────────────────────────────────────────────────────

/// Riverpod provider for the application [GoRouter].
///
/// The router listens to [authStateProvider] via [refreshListenable] so that
/// navigation is re-evaluated automatically on every auth state change.
final appRouterProvider = Provider<GoRouter>((ref) {
  // A [ValueNotifier] that fires whenever the auth state stream emits.
  // GoRouter's [refreshListenable] accepts any [Listenable].
  final authNotifier = _AuthStateNotifier(ref);

  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.login,
    refreshListenable: authNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isOnLoginPage = state.matchedLocation == AppRoutes.login;

      if (!isLoggedIn && !isOnLoginPage) {
        // Not authenticated → redirect to login.
        return AppRoutes.login;
      }

      if (isLoggedIn && isOnLoginPage) {
        // Already authenticated → skip login and go home.
        return AppRoutes.home;
      }

      // No redirect needed.
      return null;
    },
    routes: [
      // ── Auth shell (no NavBar) ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        // TODO(auth): Replace with LoginScreen when iterating on feature views.
        builder: (context, state) => const _PlaceholderScreen(label: 'Login'),
      ),

      // ── Main shell (with NavBar) ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) =>
            ScaffoldWithNavbar(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            // TODO: Replace with HomeScreen.
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Home'),
          ),
          GoRoute(
            path: AppRoutes.ledger,
            name: 'ledger',
            // TODO: Replace with LedgerScreen.
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Ledger'),
          ),
          GoRoute(
            path: AppRoutes.friends,
            name: 'friends',
            // TODO: Replace with FriendsScreen.
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Friends'),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            // TODO: Replace with SettingsScreen.
            builder: (context, state) =>
                const _PlaceholderScreen(label: 'Settings'),
          ),
        ],
      ),
    ],
  );
});

// ── Internal helpers ───────────────────────────────────────────────────────────

/// Bridges Riverpod's [authStateProvider] stream to a [ChangeNotifier] that
/// [GoRouter] can observe via its [refreshListenable] hook.
class _AuthStateNotifier extends ChangeNotifier {
  _AuthStateNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}

/// Placeholder widget used for all unimplemented routes during the scaffold
/// phase. Will be replaced by concrete screen widgets in subsequent iterations.
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          '$label\n(placeholder)',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ),
    );
  }
}
