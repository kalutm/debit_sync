import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_providers.dart';
import '../../ledger/providers/ledger_providers.dart';
import '../../ledger/widgets/settle_up_modal.dart';
import '../providers/friends_providers.dart';

/// Displays the user's recent contacts and allows them to quickly
/// initiate a new debit request.
class FriendsView extends ConsumerWidget {
  const FriendsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final currentUser = ref.watch(currentAppUserProvider).valueOrNull;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final recentsAsync = ref.watch(recentsStreamProvider(currentUser.uid));
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Friends')),
      body: recentsAsync.when(
        data: (recents) {
          if (recents.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: cs.primary.withAlpha(120),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No recent friends',
                    style: tt.headlineSmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send or receive a request to see them here.',
                    style: tt.bodyMedium?.copyWith(color: cs.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: recents.length,
            itemBuilder: (context, index) {
              final friend = recents[index];
              return Consumer(
                builder: (context, ref, child) {
                  final netBalanceAsync = ref.watch(
                    netBalanceProvider(friend.friendUid),
                  );
                  final balance = netBalanceAsync.valueOrNull ?? 0;

                  Widget subtitle = Text(friend.email);
                  if (balance != 0) {
                    final isOwed = balance > 0;
                    final amt = (balance.abs() / 100).toStringAsFixed(2);
                    subtitle = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(friend.email),
                        Text(
                          isOwed ? 'Owes you \$$amt' : 'You owe \$$amt',
                          style: TextStyle(
                            color: isOwed ? cs.primary : cs.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  }
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        friend.name.isNotEmpty
                            ? friend.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      friend.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: subtitle,
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: cs.primary),
                      onSelected: (value) {
                        if (value == 'request') {
                          context.push(
                            '${AppRoutes.newDebit}?email=${friend.email}',
                          );
                        } else if (value == 'settle') {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                            ),
                            builder: (_) => SettleUpModal(
                              friend: friend,
                              balance: balance,
                              currentUserUid: currentUser.uid,
                            ),
                          );
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'request',
                          child: Text('Request Debit'),
                        ),
                        const PopupMenuItem(
                          value: 'settle',
                          child: Text('Settle Up'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: \$err')),
      ),
    );
  }
}
