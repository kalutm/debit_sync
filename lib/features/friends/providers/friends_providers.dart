import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/recent_friend.dart';
import '../repositories/friends_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

/// Provides the singleton [FriendsRepository] instance.
final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepository(),
  name: 'friendsRepositoryProvider',
);

// ── Streams ────────────────────────────────────────────────────────────────────

/// Emits a real-time ordered list of [RecentFriend]s for the given [uid].
///
/// This is a family provider — pass the current user's UID as the argument:
/// ```dart
/// final recents = ref.watch(recentsStreamProvider(currentUser.uid));
/// ```
final recentsStreamProvider = StreamProvider.family<List<RecentFriend>, String>(
  (ref, uid) => ref.watch(friendsRepositoryProvider).watchRecents(uid),
  name: 'recentsStreamProvider',
);
