import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../friends/providers/friends_providers.dart';
import '../../../services/services_providers.dart';
import '../models/transaction_model.dart';
import '../repositories/ledger_repository.dart';

// ── Repository ─────────────────────────────────────────────────────────────────

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(
    friendsRepository: ref.watch(friendsRepositoryProvider),
    authRepository: ref.watch(authRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  ),
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

/// Calculates the net balance between the current user and a specific friend.
/// Positive = friend owes the current user.
/// Negative = current user owes the friend.
/// Calculates the net balance between the current user and a specific friend.
/// Positive = friend owes the current user.
/// Negative = current user owes the friend.
final netBalanceProvider = Provider.family<int, String>((ref, friendUid) {
  final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
  if (currentUser == null) return 0;

  final asyncTxs = ref.watch(userTransactionsStreamProvider(currentUser.uid));
  final transactions = asyncTxs.valueOrNull ?? [];

  int balance = 0;
  final sortedTxs = transactions.toList().reversed;
  for (final tx in sortedTxs) {
    if (tx.status != TransactionStatus.accepted) continue;

    final isCounterparty =
        tx.requestedBy == friendUid || tx.requestedFrom == friendUid;
    if (!isCounterparty) continue;

    if (tx.type == TransactionType.netSettlement) {
      balance = 0;
    } else if (tx.type == TransactionType.debit) {
      if (tx.requestedFrom == currentUser.uid) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    } else if (tx.type == TransactionType.payback) {
      if (tx.requestedBy == currentUser.uid) {
        balance += tx.amount;
      } else {
        balance -= tx.amount;
      }
    }
  }

  return balance;
});
