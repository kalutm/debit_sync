import 'package:cloud_firestore/cloud_firestore.dart';

// ── Enums ──────────────────────────────────────────────────────────────────────

/// The category of a ledger transaction.
enum TransactionType {
  /// A new debt — Party A owes Party B [amount] cents.
  debit,

  /// A full or partial repayment against a [linkedDebitId].
  payback,

  /// A special settlement that nets opposing debts to zero.
  netSettlement;

  /// Serialization key stored in Firestore.
  String get value => switch (this) {
        TransactionType.debit => 'debit',
        TransactionType.payback => 'payback',
        TransactionType.netSettlement => 'net_settlement',
      };

  static TransactionType fromValue(String value) => switch (value) {
        'debit' => TransactionType.debit,
        'payback' => TransactionType.payback,
        'net_settlement' => TransactionType.netSettlement,
        _ => throw ArgumentError('Unknown TransactionType value: $value'),
      };
}

/// The lifecycle status of a transaction request.
enum TransactionStatus {
  /// Awaiting acceptance by [requestedFrom].
  pending,

  /// Accepted and permanently committed to the ledger.
  accepted,

  /// Declined — the amount is not owed.
  rejected;

  /// Serialization key stored in Firestore.
  String get value => switch (this) {
        TransactionStatus.pending => 'pending',
        TransactionStatus.accepted => 'accepted',
        TransactionStatus.rejected => 'rejected',
      };

  static TransactionStatus fromValue(String value) => switch (value) {
        'pending' => TransactionStatus.pending,
        'accepted' => TransactionStatus.accepted,
        'rejected' => TransactionStatus.rejected,
        _ => throw ArgumentError('Unknown TransactionStatus value: $value'),
      };
}

// ── Model ──────────────────────────────────────────────────────────────────────

/// Data model for a transaction document at `/transactions/{id}`.
///
/// ## Integer-only currency
/// [amount] and [remainingAmount] are always stored in the **smallest currency
/// unit** (e.g. cents for USD). Floating-point arithmetic is strictly forbidden
/// — use `int` throughout the entire data layer.
///
/// ## Zero-trust lifecycle
/// A transaction begins as [TransactionStatus.pending] and only becomes a real
/// ledger entry once the counterparty explicitly accepts it.
final class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.type,
    required this.requestedBy,
    required this.requestedFrom,
    required this.amount,
    required this.remainingAmount,
    required this.status,
    required this.createdAt,
    this.linkedDebitId,
    this.notes,
  });

  /// Firestore document ID.
  final String id;

  final TransactionType type;

  /// UID of the user who initiated the request.
  final String requestedBy;

  /// UID of the counterparty who must accept or reject.
  final String requestedFrom;

  /// Total amount in the smallest currency unit (e.g. cents). Must be > 0.
  final int amount;

  /// Remaining unpaid amount after partial paybacks. Must be >= 0.
  final int remainingAmount;

  final TransactionStatus status;

  /// For [TransactionType.payback] only — the ID of the parent debit.
  final String? linkedDebitId;

  /// Optional memo or description for this transaction.
  final String? notes;

  final DateTime createdAt;

  // ── Serialization ──────────────────────────────────────────────────────────

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] as String,
      type: TransactionType.fromValue(json['type'] as String),
      requestedBy: json['requestedBy'] as String,
      requestedFrom: json['requestedFrom'] as String,
      amount: (json['amount'] as num).toInt(),
      remainingAmount: (json['remainingAmount'] as num).toInt(),
      status: TransactionStatus.fromValue(json['status'] as String),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      linkedDebitId: json['linkedDebitId'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.value,
      'requestedBy': requestedBy,
      'requestedFrom': requestedFrom,
      'amount': amount,
      'remainingAmount': remainingAmount,
      'status': status.value,
      'createdAt': Timestamp.fromDate(createdAt),
      'linkedDebitId': linkedDebitId,
      'notes': notes,
    };
  }

  // ── Convenience ────────────────────────────────────────────────────────────

  TransactionModel copyWith({
    String? id,
    TransactionType? type,
    String? requestedBy,
    String? requestedFrom,
    int? amount,
    int? remainingAmount,
    TransactionStatus? status,
    DateTime? createdAt,
    String? linkedDebitId,
    String? notes,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedFrom: requestedFrom ?? this.requestedFrom,
      amount: amount ?? this.amount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      linkedDebitId: linkedDebitId ?? this.linkedDebitId,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() => 'TransactionModel(id: $id, type: ${type.value}, '
      'amount: $amount, status: ${status.value})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
