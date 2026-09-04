import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a user document stored at `/users/{uid}`.
///
/// All monetary interactions are keyed to this user's [uid].
/// [tokens] is a list of FCM registration tokens (one per device).
final class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.tokens,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;

  /// FCM device registration tokens. A user may have multiple active devices.
  final List<String> tokens;

  final DateTime createdAt;

  // ── Serialization ──────────────────────────────────────────────────────────

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      uid: json['uid'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      tokens: List<String>.from(json['tokens'] as List? ?? []),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'tokens': tokens,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  // ── Convenience ────────────────────────────────────────────────────────────

  AppUser copyWith({
    String? uid,
    String? name,
    String? email,
    List<String>? tokens,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      email: email ?? this.email,
      tokens: tokens ?? this.tokens,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'AppUser(uid: $uid, name: $name, email: $email, tokens: $tokens)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          uid == other.uid &&
          email == other.email;

  @override
  int get hashCode => Object.hash(uid, email);
}
