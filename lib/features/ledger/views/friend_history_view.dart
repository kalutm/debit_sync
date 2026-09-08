import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/ledger_providers.dart';
import '../widgets/transaction_card.dart';

class FriendHistoryView extends ConsumerWidget {
  const FriendHistoryView({super.key, required this.friendUid});

  final String friendUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = currentUser.uid;
    final historyAsync = ref.watch(userTransactionsStreamProvider(uid));

    final friendAsync = ref.watch(userProfileStreamProvider(friendUid));
    final friendName = friendAsync.valueOrNull?.name ?? 'Friend';

    return historyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text(e.toString()))),
      data: (transactions) {
        final filtered = transactions.where((tx) {
          return tx.requestedBy == friendUid || tx.requestedFrom == friendUid;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('$friendName History', style: const TextStyle(fontWeight: FontWeight.w700)),
            scrolledUnderElevation: 0,
          ),
          body: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No transactions with this friend',
                    style: TextStyle(color: cs.outline),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(userTransactionsStreamProvider(uid));
                    await ref.read(userTransactionsStreamProvider(uid).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => TransactionCard(
                      transaction: filtered[i],
                      currentUserUid: uid,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
