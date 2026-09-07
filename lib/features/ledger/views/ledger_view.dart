import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';
import '../widgets/transaction_card.dart';

// ── LedgerView ─────────────────────────────────────────────────────────────────
/// The main transaction dashboard, split into two tabs:
///
// **Inbox ("Action Required")** — streams [pendingInboxProvider]:
///   transactions where [TransactionModel.requestedFrom] == current user UID
///   and status is [TransactionStatus.pending]. Each card exposes Accept/Reject.
///
/// **History** — streams [userTransactionsStreamProvider]:
///   every transaction the current user is party to, in descending date order.
///
/// The FAB is a placeholder for the "New Transaction" flow (future iteration).
class LedgerView extends ConsumerStatefulWidget {
  const LedgerView({super.key});

  @override
  ConsumerState<LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends ConsumerState<LedgerView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Rebuild when the tab animation settles so the FAB label can update.
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────
  void _onFabPressed(BuildContext context) {
        context.push('/new-debit');
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Resolve the current user — if null, auth is still initialising.
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = currentUser.uid;
    final pendingAsync = ref.watch(pendingInboxProvider(uid));
    final historyAsync = ref.watch(userTransactionsStreamProvider(uid));
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      // ── AppBar with pill-shaped segmented TabBar ─────────────────────────
      appBar: AppBar(
        title: const Text(
          'Ledger',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        scrolledUnderElevation: 0,
        bottom: _buildTabBar(cs, pendingCount),
      ),
      // ── FAB ──────────────────────────────────────────────────────────────
      floatingActionButton: _Fab(onPressed: () => _onFabPressed(context)),
      // ── Tab content ───────────────────────────────────────────────────────
      body: TabBarView(
        controller: _tabController,
        children: [
          // Inbox — pending requests where current user must decide
          _TransactionListTab(
            asyncValue: pendingAsync,
            currentUserUid: uid,
            emptyIcon: Icons.mark_email_read_outlined,
            emptyTitle: 'All Clear',
            emptySubtitle:
                "No pending requests right now.\nWhen a friend sends you a debit or payback, it'll show up here.",
          ),
          // History — all transactions for current user
          _TransactionListTab(
            asyncValue: historyAsync,
            currentUserUid: uid,
            emptyIcon: Icons.receipt_long_outlined,
            emptyTitle: 'Your Ledger is Clean',
            emptySubtitle:
                'No transactions yet.\nTap  +  to record a new debit with a friend.',
          ),
        ],
      ),
    );
  }

  // ── Private builders ───────────────────────────────────────────────────────
  PreferredSizeWidget _buildTabBar(ColorScheme cs, int pendingCount) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(58),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            // Slightly elevated surface to contrast against the page background.
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            // Fill the selected tab with the primary colour.
            indicator: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.all(3),
            labelColor: cs.onPrimary,
            unselectedLabelColor: cs.onSurfaceVariant,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            tabs: [
              // Inbox tab — shows a count badge when > 0 pending items.
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Inbox'),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 6),
                      _CountBadge(count: pendingCount),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'History'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Transaction list tab ───────────────────────────────────────────────────────
/// Renders one tab's worth of transactions from an [AsyncValue], with a
/// loading spinner, polished empty state, error state, and a [ListView] of
/// [TransactionCard] widgets.
class _TransactionListTab extends StatelessWidget {
  const _TransactionListTab({
    required this.asyncValue,
    required this.currentUserUid,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
  });
  final AsyncValue<List<TransactionModel>> asyncValue;
  final String currentUserUid;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
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
        return ListView.builder(
          // Extra bottom padding so the last card clears the FAB.
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: transactions.length,
          itemBuilder: (_, i) => TransactionCard(
            transaction: transactions[i],
            currentUserUid: currentUserUid,
          ),
        );
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

// ── FAB ────────────────────────────────────────────────────────────────────────
class _Fab extends StatelessWidget {
  const _Fab({required this.onPressed});
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: cs.primary,
      foregroundColor: cs.onPrimary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

// ── Count badge ────────────────────────────────────────────────────────────────
/// Compact orange badge showing the number of pending inbox items.
/// Caps the displayed number at 99 to prevent layout overflow.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
    );
  }
}
