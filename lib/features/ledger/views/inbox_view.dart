import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/providers/auth_providers.dart';
import '../../../core/widgets/app_page_title.dart';
import '../providers/ledger_providers.dart';
import '../widgets/transaction_list_tab.dart';

class InboxView extends ConsumerWidget {
  const InboxView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final uid = currentUser.uid;
    final pendingAsync = ref.watch(pendingInboxProvider(uid));
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppPageTitle('Requests'),
            if (pendingCount > 0) ...[
              const SizedBox(width: 8),
              _CountBadge(count: pendingCount),
            ],
          ],
        ),
        scrolledUnderElevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/new-debit'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: TransactionListTab(
        asyncValue: pendingAsync,
        currentUserUid: uid,
        emptyIcon: Icons.mark_email_read_outlined,
        emptyTitle: 'All Clear',
        emptySubtitle:
            "No pending requests right now.\nWhen a friend sends you a debit or payback, it'll show up here.",
        fabPadding: true,
        onRefresh: () async {
          ref.invalidate(pendingInboxProvider(uid));
          await ref.read(pendingInboxProvider(uid).future);
        },
      ),
    );
  }
}

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
