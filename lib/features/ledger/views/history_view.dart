import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../../../core/widgets/app_page_title.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';
import '../widgets/transaction_card.dart';

enum _FilterOption { all, lended, borrowed, payback }

class HistoryView extends ConsumerStatefulWidget {
  const HistoryView({super.key});

  @override
  ConsumerState<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends ConsumerState<HistoryView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _FilterOption _selectedFilter = _FilterOption.all;

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

    return Scaffold(
      appBar: AppBar(
        title: const AppPageTitle('Ledger'),
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
                    hintText: 'Search notes or amount...',
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
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedFilter == _FilterOption.all,
                        onSelected: (_) =>
                            setState(() => _selectedFilter = _FilterOption.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Lended',
                        isSelected: _selectedFilter == _FilterOption.lended,
                        onSelected: (_) => setState(
                          () => _selectedFilter = _FilterOption.lended,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Borrowed',
                        isSelected: _selectedFilter == _FilterOption.borrowed,
                        onSelected: (_) => setState(
                          () => _selectedFilter = _FilterOption.borrowed,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Payback',
                        isSelected: _selectedFilter == _FilterOption.payback,
                        onSelected: (_) => setState(
                          () => _selectedFilter = _FilterOption.payback,
                        ),
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
            if (tx.type == TransactionType.netSettlement) return false;

            bool matchesFilter = false;
            switch (_selectedFilter) {
              case _FilterOption.all:
                matchesFilter = true;
                break;
              case _FilterOption.lended:
                matchesFilter =
                    tx.type == TransactionType.debit && tx.requestedFrom == uid;
                break;
              case _FilterOption.borrowed:
                matchesFilter =
                    tx.type == TransactionType.debit && tx.requestedBy == uid;
                break;
              case _FilterOption.payback:
                matchesFilter = tx.type == TransactionType.payback;
                break;
            }

            if (!matchesFilter) return false;

            if (_searchQuery.isNotEmpty) {
              final amountStr = (tx.amount / 100).toStringAsFixed(2);
              final rawAmountStr = tx.amount.toString();

              final notesMatch =
                  tx.notes?.toLowerCase().contains(_searchQuery) ?? false;
              final amountMatch =
                  amountStr.contains(_searchQuery) ||
                  rawAmountStr.contains(_searchQuery);

              if (!notesMatch && !amountMatch) return false;
            }

            return true;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                transactions.isEmpty
                    ? 'Your ledger is clean'
                    : 'No matching transactions',
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
