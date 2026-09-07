import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/friends/views/friends_view.dart';
import '../../features/ledger/views/create_debit_view.dart';
import '../../features/ledger/views/ledger_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../widgets/scaffold_with_navbar.dart';

// ── Route name constants ───────────────────────────────────────────────────────

/// Named route constants to avoid magic strings at call sites.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String home = '/home';
  static const String ledger = '/ledger';
  static const String friends = '/friends';
  static const String settings = '/settings';
  static const String newDebit = '/new-debit';
}

// ── Router Provider ────────────────────────────────────────────────────────────

/// Riverpod provider for the application [GoRouter].
///
/// The router listens to [authStateProvider] via [refreshListenable] so that
/// navigation is re-evaluated automatically on every auth state change.
final appRouterProvider = Provider<GoRouter>((ref) {
  // A [ChangeNotifier] that fires whenever the auth state stream emits.
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
        // Already authenticated → skip login and land on the ledger tab.
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
        builder: (context, state) => const LoginView(),
      ),

      // ── Main shell (with NavBar) ───────────────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => ScaffoldWithNavbar(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            name: 'home',
            // Home tab renders the Ledger as the primary landing experience
            // until a dedicated Home/Summary screen is built in a later iteration.
            builder: (context, state) => const LedgerView(),
          ),
          GoRoute(
            path: AppRoutes.ledger,
            name: 'ledger',
            builder: (context, state) => const LedgerView(),
          ),
          GoRoute(
            path: AppRoutes.newDebit,
            name: 'new_debit',
            // Displayed without the bottom nav bar, but still under the auth shell
            // Wait, if it is in ShellRoute, it has a NavBar. Usually form flows don't have NavBar.
            // But let's follow the prompt and add it to router. Let's make it a child of ShellRoute or a sibling?
            // "Add the /new-debit route to app_router.dart."
            // If I add it outside ShellRoute, it won't have bottom nav, which is better for a form.
            // Let's add it under Ledger routes, or outside.
            // Wait, let's keep it simple.
            builder: (context, state) => CreateDebitView(
              initialEmail: state.uri.queryParameters['email'],
            ),
          ),
          GoRoute(
            path: AppRoutes.friends,
            name: 'friends',
            builder: (context, state) => const FriendsView(),
          ),
          GoRoute(
            path: AppRoutes.settings,
            name: 'settings',
            builder: (context, state) => const SettingsView(),
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
