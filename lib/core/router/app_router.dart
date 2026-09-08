import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/auth/views/login_view.dart';
import '../../features/friends/views/friends_view.dart';
import '../../features/ledger/views/create_debit_view.dart';
import '../../features/ledger/views/friend_history_view.dart';
import '../../features/ledger/views/history_view.dart';
import '../../features/ledger/views/inbox_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../widgets/scaffold_with_navbar.dart';

// ── Route name constants ───────────────────────────────────────────────────────

/// Named route constants to avoid magic strings at call sites.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String inbox = '/inbox';
  static const String history = '/history';
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
        // Already authenticated → skip login and land on the inbox tab.
        return AppRoutes.inbox;
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
            path: AppRoutes.inbox,
            name: 'inbox',
            builder: (context, state) => const InboxView(),
          ),
          GoRoute(
            path: AppRoutes.history,
            name: 'history',
            builder: (context, state) => const HistoryView(),
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
            routes: [
              GoRoute(
                path: ':friendUid',
                name: 'friend_history',
                builder: (context, state) => FriendHistoryView(
                  friendUid: state.pathParameters['friendUid']!,
                ),
              ),
            ],
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
