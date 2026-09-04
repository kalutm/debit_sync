/// Centralized Firestore path constants.
///
/// All collection and document path construction lives here, ensuring a single
/// source of truth and preventing typo-driven path drift across repositories.
abstract final class FirestorePaths {
  // ── Top-level collections ──────────────────────────────────────────────────

  /// `/users`
  static const String usersCollection = 'users';

  /// `/transactions`
  static const String transactionsCollection = 'transactions';

  // ── Document paths ─────────────────────────────────────────────────────────

  /// `/users/{uid}`
  static String user(String uid) => '$usersCollection/$uid';

  /// `/transactions/{txId}`
  static String transaction(String txId) =>
      '$transactionsCollection/$txId';

  // ── Sub-collections ────────────────────────────────────────────────────────

  /// `/users/{uid}/recents`
  static String recentsCollection(String uid) =>
      '$usersCollection/$uid/recents';

  /// `/users/{uid}/recents/{friendUid}`
  static String recent(String uid, String friendUid) =>
      '${recentsCollection(uid)}/$friendUid';
}
