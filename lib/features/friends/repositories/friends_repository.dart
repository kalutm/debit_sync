import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../models/recent_friend.dart';

/// Repository managing the `/users/{uid}/recents/{friendUid}` sub-collection.
///
/// Recents represent the set of users a given user has interacted with via
/// the ledger. The list is automatically updated by [LedgerRepository] on
/// every accepted transaction, keeping it fresh without manual maintenance.
final class FriendsRepository {
  FriendsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of recent friends for [uid], ordered by
  /// most-recently-interacted-with first.
  ///
  /// TODO: Add a Firestore composite index on (lastInteractedAt DESC) for
  /// the recents sub-collection if needed.
  Stream<List<RecentFriend>> watchRecents(String uid) {
    return _firestore
        .collection(FirestorePaths.recentsCollection(uid))
        .orderBy('lastInteractedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => RecentFriend.fromJson(doc.data()))
              .toList(),
        );
  }

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates or updates the recent-friend record for [friend] under [uid].
  ///
  /// Always writes with merge so that existing fields (e.g. name) are
  /// preserved if [RecentFriend] is partially constructed.
  Future<void> upsertRecent(String uid, RecentFriend friend) async {
    await _firestore
        .doc(FirestorePaths.recent(uid, friend.friendUid))
        .set(friend.toMap(), SetOptions(merge: true));
  }

  // ── Reads (one-shot) ───────────────────────────────────────────────────────

  /// Returns a single page of the most recent contacts for [uid].
  ///
  /// Useful for auto-complete pickers that don't need a live stream.
  Future<List<RecentFriend>> fetchRecents(String uid, {int limit = 20}) async {
    final snap = await _firestore
        .collection(FirestorePaths.recentsCollection(uid))
        .orderBy('lastInteractedAt', descending: true)
        .limit(limit)
        .get();

    return snap.docs
        .map((doc) => RecentFriend.fromJson(doc.data()))
        .toList();
  }
}
