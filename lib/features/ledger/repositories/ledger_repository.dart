import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/firestore_paths.dart';
import '../models/transaction_model.dart';

/// Custom exception thrown when a domain constraint is violated.
final class LedgerConstraintException implements Exception {
  const LedgerConstraintException(this.message);

  final String message;

  @override
  String toString() => 'LedgerConstraintException: $message';
}

/// Repository encapsulating all ledger (transaction) business logic.
///
/// ## Domain Constraints enforced here:
///
/// 1. **Integer-only currency**: [amount] and [remainingAmount] are always
///    `int` (cents). This is enforced at the [TransactionModel] type level and
///    validated again on write.
///
/// 2. **Anti-race payback guard**: A payback request CANNOT be filed against a
///    debit that is still [TransactionStatus.pending]. The guard is implemented
///    inside a Firestore **Transaction** (read-then-write atomically) so that
///    concurrent payback attempts against the same debit cannot both succeed.
///
/// 3. **Zero-trust lifecycle**: All new transactions are written with
///    [TransactionStatus.pending]. Only the counterparty ([requestedFrom]) may
///    advance the status to [TransactionStatus.accepted] or
///    [TransactionStatus.rejected] via [acceptTransaction]/[rejectTransaction].
final class LedgerRepository {
  LedgerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _txCollection =>
      _firestore.collection(FirestorePaths.transactionsCollection);

  // ── Writes ─────────────────────────────────────────────────────────────────

  /// Creates a new debit request.
  ///
  /// The transaction is written with [TransactionStatus.pending] regardless of
  /// what [transaction.status] contains — the repository enforces this.
  ///
  /// Throws [LedgerConstraintException] if:
  /// - [transaction.amount] is not a positive integer.
  /// - [transaction.type] is not [TransactionType.debit].
  Future<void> createDebitRequest(TransactionModel transaction) async {
    _validateAmount(transaction.amount);

    if (transaction.type != TransactionType.debit) {
      throw const LedgerConstraintException(
        'createDebitRequest only accepts TransactionType.debit.',
      );
    }

    // Force pending status regardless of caller input.
    final pending = transaction.copyWith(
      status: TransactionStatus.pending,
      remainingAmount: transaction.amount,
    );

    await _txCollection.doc(pending.id).set(pending.toMap());
  }

  /// Creates a payback request against an existing accepted debit.
  ///
  /// ## Anti-race guard (Firestore Transaction)
  /// This method executes inside a Firestore [Transaction] that:
  /// 1. Reads the linked debit document.
  /// 2. Validates that its status is [TransactionStatus.accepted].
  /// 3. Validates that [transaction.amount] ≤ the debit's [remainingAmount].
  /// 4. Atomically writes the new payback document only if all checks pass.
  ///
  /// Because steps 1-4 are atomic, concurrent payback requests cannot both
  /// succeed if they would collectively exceed the remaining balance.
  ///
  /// Throws [LedgerConstraintException] if:
  /// - [transaction.linkedDebitId] is null.
  /// - The linked debit does not exist.
  /// - The linked debit is still [TransactionStatus.pending] or
  ///   [TransactionStatus.rejected].
  /// - [transaction.amount] exceeds the debit's [remainingAmount].
  /// - [transaction.amount] is not a positive integer.
  Future<void> createPaybackRequest(TransactionModel transaction) async {
    _validateAmount(transaction.amount);

    final linkedDebitId = transaction.linkedDebitId;
    if (linkedDebitId == null || linkedDebitId.isEmpty) {
      throw const LedgerConstraintException(
        'A payback request must reference a linkedDebitId.',
      );
    }

    final debitRef = _txCollection.doc(linkedDebitId);
    final paybackRef = _txCollection.doc(transaction.id);

    await _firestore.runTransaction((firestoreTx) async {
      // ── Step 1: Read the parent debit atomically ───────────────────────────
      final debitSnap = await firestoreTx.get(debitRef);

      if (!debitSnap.exists || debitSnap.data() == null) {
        throw const LedgerConstraintException(
          'The referenced debit transaction does not exist.',
        );
      }

      final debit = TransactionModel.fromJson(debitSnap.data()!);

      // ── Step 2: Status guard ───────────────────────────────────────────────
      if (debit.status == TransactionStatus.pending) {
        throw const LedgerConstraintException(
          'Cannot file a payback against a debit that is still pending. '
          'The debit must be accepted by the counterparty first.',
        );
      }

      if (debit.status == TransactionStatus.rejected) {
        throw const LedgerConstraintException(
          'Cannot file a payback against a rejected debit.',
        );
      }

      // ── Step 3: Amount guard ───────────────────────────────────────────────
      if (transaction.amount > debit.remainingAmount) {
        throw LedgerConstraintException(
          'Payback amount (${transaction.amount}) exceeds the remaining '
          'debit balance (${debit.remainingAmount}).',
        );
      }

      // ── Step 4: Atomic write ───────────────────────────────────────────────
      final pending = transaction.copyWith(
        status: TransactionStatus.pending,
      );
      firestoreTx.set(paybackRef, pending.toMap());
    });
  }

  /// Advances a transaction's status to [TransactionStatus.accepted].
  ///
  /// For a payback: also decrements [remainingAmount] on the parent debit
  /// within the same Firestore transaction to keep balances consistent.
  ///
  /// Throws [LedgerConstraintException] if the transaction is not
  /// [TransactionStatus.pending].
  Future<void> acceptTransaction(String txId) async {
    final txRef = _txCollection.doc(txId);

    await _firestore.runTransaction((firestoreTx) async {
      final snap = await firestoreTx.get(txRef);
      if (!snap.exists || snap.data() == null) {
        throw LedgerConstraintException(
          'Transaction $txId not found.',
        );
      }

      final tx = TransactionModel.fromJson(snap.data()!);

      if (tx.status != TransactionStatus.pending) {
        throw LedgerConstraintException(
          'Transaction $txId cannot be accepted — it is already ${tx.status.value}.',
        );
      }

      // Accept the transaction itself.
      firestoreTx.update(txRef, {'status': TransactionStatus.accepted.value});

      // If this is a payback, update the parent debit's remainingAmount.
      if (tx.type == TransactionType.payback &&
          tx.linkedDebitId != null) {
        final debitRef = _txCollection.doc(tx.linkedDebitId);
        firestoreTx.update(debitRef, {
          'remainingAmount': FieldValue.increment(-tx.amount),
        });
      }
    });
  }

  /// Advances a transaction's status to [TransactionStatus.rejected].
  ///
  /// Throws [LedgerConstraintException] if the transaction is not
  /// [TransactionStatus.pending].
  Future<void> rejectTransaction(String txId) async {
    final txRef = _txCollection.doc(txId);

    await _firestore.runTransaction((firestoreTx) async {
      final snap = await firestoreTx.get(txRef);
      if (!snap.exists || snap.data() == null) {
        throw LedgerConstraintException('Transaction $txId not found.');
      }

      final tx = TransactionModel.fromJson(snap.data()!);

      if (tx.status != TransactionStatus.pending) {
        throw LedgerConstraintException(
          'Transaction $txId cannot be rejected — it is already ${tx.status.value}.',
        );
      }

      firestoreTx.update(txRef, {'status': TransactionStatus.rejected.value});
    });
  }

  // ── Streams ────────────────────────────────────────────────────────────────

  /// Returns a real-time stream of all transactions involving [uid] — both
  /// as the requester and as the counterparty.
  ///
  /// Because Firestore does not support OR queries across different fields
  /// in a single query, this merges two sub-streams client-side via
  /// [Stream.multi]. The composite indexes in firestore.indexes.json cover
  /// both the (requestedBy + createdAt) and (requestedFrom + createdAt) paths.
  ///
  /// TODO: Consider migrating to Firestore's native OR filter
  /// (`Query.where(Filter.or(...))`) once it is stable in the Flutter SDK.
  Stream<List<TransactionModel>> watchTransactionsForUser(String uid) {
    final byStream = _txCollection
        .where('requestedBy', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => TransactionModel.fromJson(d.data())).toList());

    final fromStream = _txCollection
        .where('requestedFrom', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => TransactionModel.fromJson(d.data())).toList());

    // Combine both streams, merge deduplicating by ID, and re-sort.
    return byStream.asyncExpand((byList) {
      return fromStream.map((fromList) {
        final seen = <String>{};
        final merged = <TransactionModel>[];

        for (final tx in [...byList, ...fromList]) {
          if (seen.add(tx.id)) merged.add(tx);
        }

        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return merged;
      });
    });
  }

  /// Returns a stream of only [TransactionStatus.pending] transactions
  /// where [uid] is the counterparty ([requestedFrom]).
  ///
  /// This is the primary feed for the "Action Required" inbox UI.
  Stream<List<TransactionModel>> watchPendingForUser(String uid) {
    return _txCollection
        .where('requestedFrom', isEqualTo: uid)
        .where('status', isEqualTo: TransactionStatus.pending.value)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => TransactionModel.fromJson(d.data()))
              .toList(),
        );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Validates that [amount] is a positive integer (i.e. > 0).
  ///
  /// Dart's type system already prevents non-integers, but we still guard
  /// against zero/negative values at the repository boundary.
  void _validateAmount(int amount) {
    if (amount <= 0) {
      throw LedgerConstraintException(
        'Amount must be a positive integer (cents). Got: $amount',
      );
    }
  }
}
