import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a recent-friend sub-document at
/// `/users/{uid}/recents/{friendUid}`.
///
/// Written/updated whenever two users interact (debit or payback requested).
/// Used to surface a fast, pre-sorted list of frequent contacts in the UI.
final class RecentFriend {
  const RecentFriend({
    required this.friendUid,
    required this.name,
    required this.email,
    required this.lastInteractedAt,
  });

  final String friendUid;
  final String name;
  final String email;

  /// Timestamp of the most recent transaction interaction between the two users.
  final DateTime lastInteractedAt;

  // ── Serialization ──────────────────────────────────────────────────────────

  factory RecentFriend.fromJson(Map<String, dynamic> json) {
    return RecentFriend(
      friendUid: json['friendUid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      lastInteractedAt:
          (json['lastInteractedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'friendUid': friendUid,
      'name': name,
      'email': email,
      'lastInteractedAt': Timestamp.fromDate(lastInteractedAt),
    };
  }

  // ── Convenience ────────────────────────────────────────────────────────────

  RecentFriend copyWith({
    String? friendUid,
    String? name,
    String? email,
    DateTime? lastInteractedAt,
  }) {
    return RecentFriend(
      friendUid: friendUid ?? this.friendUid,
      name: name ?? this.name,
      email: email ?? this.email,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
    );
  }

  @override
  String toString() =>
      'RecentFriend(friendUid: $friendUid, name: $name, email: $email)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentFriend &&
          runtimeType == other.runtimeType &&
          friendUid == other.friendUid;

  @override
  int get hashCode => friendUid.hashCode;
}
