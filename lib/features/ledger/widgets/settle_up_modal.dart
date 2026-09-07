import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../friends/models/recent_friend.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';

class SettleUpModal extends ConsumerStatefulWidget {
  const SettleUpModal({
    super.key,
    required this.friend,
    required this.balance,
    required this.currentUserUid,
  });
  final RecentFriend friend;
  final int balance;
  final String currentUserUid;
  @override
  ConsumerState<SettleUpModal> createState() => _SettleUpModalState();
}

class _SettleUpModalState extends ConsumerState<SettleUpModal> {
  bool _isLoading = false;
  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final tx = TransactionModel(
        id: const Uuid().v4(),
        type: TransactionType.netSettlement,
        status: TransactionStatus.pending,
        requestedBy: widget.currentUserUid,
        requestedFrom: widget.friend.friendUid,
        amount: widget.balance.abs(),
        remainingAmount: 0,
        createdAt: DateTime.now(),
      );
      await ref.read(ledgerRepositoryProvider).createNetSettlementRequest(tx);
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Settle Up',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          if (widget.balance == 0) ...[
            const SizedBox(height: 16),
            const Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            Text(
              'You and \${widget.friend.name} are all settled up!',
              style: tt.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.tonal(
              onPressed: () => context.pop(),
              child: const Text('Close'),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Text(
              widget.balance > 0
                  ? '\${widget.friend.name} owes you'
                  : 'You owe \${widget.friend.name}',
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '\$\${(widget.balance.abs() / 100).toStringAsFixed(2)}',
              style: tt.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.balance > 0 ? cs.primary : cs.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Send Settlement Request',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
