import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/transaction_model.dart';
import '../repositories/ledger_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

/// Provides the singleton [LedgerRepository] instance.
final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(),
  name: 'ledgerRepositoryProvider',
);

// ── Streams ────────────────────────────────────────────────────────────────────

/// Emits all transactions (as requester or counterparty) for the given [uid],
/// sorted by [TransactionModel.createdAt] descending.
///
/// Family provider — pass the current user's UID:
/// ```dart
/// final txStream = ref.watch(userTransactionsStreamProvider(uid));
/// ```
final userTransactionsStreamProvider =
    StreamProvider.family<List<TransactionModel>, String>(
  (ref, uid) =>
      ref.watch(ledgerRepositoryProvider).watchTransactionsForUser(uid),
  name: 'userTransactionsStreamProvider',
);

/// Emits only the [TransactionStatus.pending] transactions where [uid] is the
/// counterparty — i.e. the "Action Required" inbox.
///
/// Family provider — pass the current user's UID:
/// ```dart
/// final inbox = ref.watch(pendingInboxProvider(uid));
/// ```
final pendingInboxProvider =
    StreamProvider.family<List<TransactionModel>, String>(
  (ref, uid) =>
      ref.watch(ledgerRepositoryProvider).watchPendingForUser(uid),
  name: 'pendingInboxProvider',
);
