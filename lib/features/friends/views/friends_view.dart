import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../auth/providers/auth_providers.dart';
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
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
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
                subtitle: Text(friend.email),
                trailing: IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: cs.primary,
                  onPressed: () {
                    context.push('${AppRoutes.newDebit}?email=${friend.email}');
                  },
                ),
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
