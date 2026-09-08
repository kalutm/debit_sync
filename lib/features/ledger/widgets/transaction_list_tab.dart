import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/transaction_model.dart';
import 'transaction_card.dart';

// ── Transaction list tab ───────────────────────────────────────────────────────
/// Renders one tab's worth of transactions from an [AsyncValue], with a
/// loading spinner, polished empty state, error state, and a [ListView] of
/// [TransactionCard] widgets.
class TransactionListTab extends StatelessWidget {
  const TransactionListTab({
    super.key,
    required this.asyncValue,
    required this.currentUserUid,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    this.onRefresh,
    this.fabPadding = false,
  });

  final AsyncValue<List<TransactionModel>> asyncValue;
  final String currentUserUid;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function()? onRefresh;
  final bool fabPadding;

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorState(error: e.toString()),
      data: (transactions) {
        if (transactions.isEmpty) {
          return _EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        final list = ListView.builder(
          // Extra bottom padding so the last card clears the FAB if needed.
          padding: EdgeInsets.only(top: 8, bottom: fabPadding ? 96 : 24),
          itemCount: transactions.length,
          itemBuilder: (_, i) => TransactionCard(
            transaction: transactions[i],
            currentUserUid: currentUserUid,
          ),
        );
        if (onRefresh != null) {
          return RefreshIndicator(
            onRefresh: onRefresh!,
            child: list,
          );
        }
        return list;
      },
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────
/// Polished centred empty-state with a large icon inside a soft circular
/// container, a title, and a descriptive subtitle.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // soft glowing icon container
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer.withAlpha(100),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withAlpha(30),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(icon, size: 44, color: cs.primary.withAlpha(200)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: tt.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              style: tt.bodyMedium?.copyWith(color: cs.outline, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: cs.error.withAlpha(180),
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load transactions',
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: tt.bodySmall?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
