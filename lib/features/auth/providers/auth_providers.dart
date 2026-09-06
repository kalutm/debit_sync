import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import '../repositories/auth_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

/// Provides the singleton [AuthRepository] instance.
///
/// Constructed with default Firebase/GoogleSignIn instances. To override in
/// tests, use [ProviderContainer] with overrides.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
  name: 'authRepositoryProvider',
);

// ── Auth State ─────────────────────────────────────────────────────────────────

/// Emits the raw Firebase [User] (or null) whenever auth state changes.
///
/// Used by [appRouterProvider] to drive the login redirect guard.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
  name: 'authStateProvider',
);

// ── AppUser Document ───────────────────────────────────────────────────────────

/// Emits the Firestore [AppUser] document for the currently signed-in user.
///
/// Depends on [authStateProvider] — emits null while unauthenticated and
/// while the document is loading after first login.
final currentAppUserProvider = StreamProvider<AppUser?>(
  (ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) return Stream.value(null);
        return ref
            .watch(authRepositoryProvider)
            .watchUserDocument(user.uid);
      },
      loading: () => Stream.value(null),
      error: (_, _) => Stream.value(null),
    );
  },
  name: 'currentAppUserProvider',
);

// ── Arbitrary user profile lookup ──────────────────────────────────────────────

/// Streams the [AppUser] document for any [uid], not just the signed-in user.
///
/// Used by [TransactionCard] to resolve counterparty names from raw UIDs stored
/// in [TransactionModel]. The provider is `autoDispose` so the underlying
/// Firestore listener is released as soon as the last subscriber (typically a
/// card that has scrolled off-screen) is unmounted.
///
/// Usage:
/// ```dart
/// final profile = ref.watch(userProfileStreamProvider(counterpartyUid));
/// final name = profile.valueOrNull?.name ?? uid;
/// ```
final userProfileStreamProvider =
    StreamProvider.autoDispose.family<AppUser?, String>(
  (ref, uid) =>
      ref.watch(authRepositoryProvider).watchUserDocument(uid),
  name: 'userProfileStreamProvider',
);
