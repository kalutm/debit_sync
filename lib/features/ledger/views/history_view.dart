import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../friends/providers/friends_providers.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';
import '../widgets/transaction_card.dart';

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  TransactionType? _selectedType;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = currentUser.uid;
    final historyAsync = ref.watch(userTransactionsStreamProvider(uid));
    final recentsAsync = ref.watch(recentsStreamProvider(uid));
    final recents = recentsAsync.valueOrNull ?? [];
    final nameMap = {for (final r in recents) r.friendUid: r.name};

    return Scaffold(
      appBar: AppBar(
        title: const Text('History', style: TextStyle(fontWeight: FontWeight.w700)),
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(116),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedType == null,
                        onSelected: (_) => setState(() => _selectedType = null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Debits',
                        isSelected: _selectedType == TransactionType.debit,
                        onSelected: (_) => setState(() => _selectedType = TransactionType.debit),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Paybacks',
                        isSelected: _selectedType == TransactionType.payback,
                        onSelected: (_) => setState(() => _selectedType = TransactionType.payback),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Settlements',
                        isSelected: _selectedType == TransactionType.netSettlement,
                        onSelected: (_) => setState(() => _selectedType = TransactionType.netSettlement),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (transactions) {
          final filtered = transactions.where((tx) {
            final matchesType = _selectedType == null || tx.type == _selectedType;
            final counterpartyUid = tx.requestedBy == uid ? tx.requestedFrom : tx.requestedBy;
            final name = nameMap[counterpartyUid] ?? 'Unknown';
            final matchesSearch = _searchQuery.isEmpty ||
                name.toLowerCase().contains(_searchQuery);
            return matchesType && matchesSearch;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                transactions.isEmpty ? 'Your ledger is clean' : 'No matching transactions',
                style: TextStyle(color: cs.outline),
              ),
            );
          }

          return RefreshIndicator(
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
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      showCheckmark: false,
    );
  }
}
