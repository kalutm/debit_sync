import 'package:debit_sync/features/ledger/widgets/payback_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';

// ── Formatting helpers ─────────────────────────────────────────────────────────
/// Formats an integer cent value as a currency string.
/// e.g. 2550 → "ETB 25.50"
String _formatAmount(int cents) {
  final value = cents / 100;
  return 'ETB ${value.toStringAsFixed(2)}';
}

/// Formats a [DateTime] as a short human-readable date.
/// Current year: "Sep 4". Previous years: "Sep 4, 2024".
String _formatDate(DateTime dt) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  if (dt.year == now.year) return '${months[dt.month - 1]} ${dt.day}';
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── TransactionCard ────────────────────────────────────────────────────────────
/// A reusable card that renders a single [TransactionModel].
///
/// ## Responsibilities
/// - Resolves the counterparty UID to a full [AppUser] profile via
///   [userProfileStreamProvider] (autoDispose — no listener leaks).
/// - Shows a coloured left-border strip that encodes the transaction direction
///   (primary = money coming in; error = money going out; tertiary = payback).
/// - Conditionally renders **Accept / Reject** action buttons when the
///   transaction is [TransactionStatus.pending] and the current user is
///   [TransactionModel.requestedFrom] (the counterparty who must decide).
/// - Wraps accept/reject calls in a per-card `_isProcessing` guard that shows a
///   spinner on the specific card being actioned, not the entire list.
class TransactionCard extends ConsumerStatefulWidget {
  const TransactionCard({
    super.key,
    required this.transaction,
    required this.currentUserUid,
  });
  final TransactionModel transaction;

  /// UID of the currently signed-in user. Used to derive transaction direction
  /// and decide whether to show the action buttons.
  final String currentUserUid;
  @override
  ConsumerState<TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends ConsumerState<TransactionCard> {
  /// True while an accept or reject call is in-flight for THIS specific card.
  bool _isProcessing = false;
  // ── Derived properties ─────────────────────────────────────────────────────
  TransactionModel get _tx => widget.transaction;
  String get _currentUid => widget.currentUserUid;

  /// The UID of the person on the opposite side of this transaction.
  String get _counterpartyUid =>
      _tx.requestedBy == _currentUid ? _tx.requestedFrom : _tx.requestedBy;

  /// True when the current user must decide on this transaction.
  bool get _showActions =>
      _tx.status == TransactionStatus.pending &&
      _tx.requestedFrom == _currentUid;

  /// True when this is a pending request that the current user sent.
  /// Shows a "Waiting for [Friend] to accept" message instead of action buttons.
  bool get _isSentPending =>
      _tx.status == TransactionStatus.pending &&
      _tx.requestedBy == _currentUid;

  /// True when this is an accepted debit, the current user is the Borrower
  /// (requestedBy), and there is still an outstanding balance to pay back.
  bool get _showPayback =>
      _tx.type == TransactionType.debit &&
      _tx.status == TransactionStatus.accepted &&
      _tx.requestedBy == _currentUid &&
      _tx.remainingAmount > 0;

  /// Left-border accent color encoding transaction direction.
  ///
  /// | Scenario                                   | Color     |
  /// |--------------------------------------------|-----------|
  /// | Debit — current user is owed               | primary   |
  /// | Debit — current user owes                  | error/red |
  /// | Payback — current user is paying           | tertiary  |
  /// | Payback — current user is receiving payment| primary   |
  Color _accentColor(ColorScheme cs) {
    if (_tx.type == TransactionType.netSettlement) {
      return cs.secondary;
    }
    if (_tx.type == TransactionType.debit) {
      return _tx.requestedFrom == _currentUid ? cs.primary : cs.error;
    }
    // Payback
    return _tx.requestedBy == _currentUid ? cs.tertiary : cs.primary;
  }

  // ── Actions ──────────────────────────────────────────────────────
  Future<void> _accept() {
    final actorName =
        ref.read(currentAppUserProvider).valueOrNull?.name ?? 'Someone';
    return _runAction(
      () => ref
          .read(ledgerRepositoryProvider)
          .acceptTransaction(_tx.id, actorName: actorName),
      successMessage: 'Transaction accepted.',
    );
  }

  Future<void> _reject() {
    final actorName =
        ref.read(currentAppUserProvider).valueOrNull?.name ?? 'Someone';
    return _runAction(
      () => ref
          .read(ledgerRepositoryProvider)
          .rejectTransaction(_tx.id, actorName: actorName),
      successMessage: 'Transaction rejected.',
    );
  }

  /// Runs [action], manages the per-card loading spinner, and surfaces errors
  /// as floating SnackBars without disrupting the rest of the list.
  Future<void> _runAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await action();
      if (mounted) _showSnackBar(successMessage);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (isError) ...[
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: isError ? cs.error : null,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Resolve counterparty profile — autoDispose cleans up when card unmounts.
    final profileAsync = ref.watch(userProfileStreamProvider(_counterpartyUid));
    final counterpartyName = profileAsync.valueOrNull?.name ?? _counterpartyUid;
    final counterpartyEmail = profileAsync.valueOrNull?.email;
    final isResolvingProfile = profileAsync.isLoading;
    final accent = _accentColor(cs);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // InkWell's splash is constrained by ClipRRect to the card shape.
      child: InkWell(
        // TODO: Navigate to transaction detail view in a future iteration.
        onTap: () {},
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Direction accent strip ─────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 4,
                  color: accent,
                ),
                // ── Card content ───────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Row 1: Avatar + name/email + status badge ──────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Counterparty avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: cs.primaryContainer,
                              child: isResolvingProfile
                                  ? SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: cs.primary,
                                      ),
                                    )
                                  : Text(
                                      counterpartyName.isNotEmpty
                                          ? counterpartyName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: cs.onPrimaryContainer,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Name + email
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    counterpartyName,
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (counterpartyEmail != null) ...[
                                    const SizedBox(height: 1),
                                    Text(
                                      counterpartyEmail,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.outline,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status badge
                            _StatusBadge(status: _tx.status),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // ── Explicit who-owes-whom ───────────────────
                        if (_tx.status == TransactionStatus.accepted &&
                            _tx.type == TransactionType.debit) ...[
                          Text(
                            _tx.requestedFrom == _currentUid
                                ? '$counterpartyName owes me ${_formatAmount(_tx.amount)}'
                                : 'I owe $counterpartyName ${_formatAmount(_tx.amount)}',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: _tx.requestedFrom == _currentUid
                                  ? cs.primary
                                  : cs.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        // ── Row 2: Amount + type + date ────────────────────
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _formatAmount(_tx.amount),
                              style: tt.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: accent,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (_tx.remainingAmount != _tx.amount &&
                                _tx.status == TransactionStatus.accepted) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(${_formatAmount(_tx.remainingAmount)} left)',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.outline,
                                ),
                              ),
                            ],
                            const Spacer(),
                            _TypeBadge(
                              type: _tx.type,
                              currentUserUid: _currentUid,
                              requestedByUid: _tx.requestedBy,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDate(_tx.createdAt),
                              style: tt.bodySmall?.copyWith(color: cs.outline),
                            ),
                          ],
                        ),
                        // ── Row 3: Optional notes ──────────────────────────
                        if (_tx.notes != null && _tx.notes!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '"${_tx.notes}"',
                            style: tt.bodySmall?.copyWith(
                              color: cs.outline,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        // ── Row 4: Accept / Reject (action required only) ──
                        if (_showActions) ...[
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withAlpha(80),
                          ),
                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _isProcessing
                                ? SizedBox(
                                    key: const ValueKey('spinner'),
                                    height: 36,
                                    child: Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: cs.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    key: const ValueKey('actions'),
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: _reject,
                                          icon: const Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Reject'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: cs.error,
                                            side: BorderSide(
                                              color: cs.error.withAlpha(130),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _accept,
                                          icon: const Icon(
                                            Icons.check_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Accept'),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2E7D32,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 10,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                        // ── Row 4b: Sent request — waiting for acceptance ──
                        if (_isSentPending) ...[
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withAlpha(80),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.orange.withAlpha(60),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 16,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Waiting for $counterpartyName to accept',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // ── Row 5: Pay Back (accepted debits only) ─────────
                        if (_showPayback) ...[
                          const SizedBox(height: 12),
                          Divider(
                            height: 1,
                            color: cs.outlineVariant.withAlpha(80),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                ),
                                builder: (_) => PaybackModal(
                                  debit: _tx,
                                  currentUserUid: _currentUid,
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: const Text('Pay Back'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status Badge ───────────────────────────────────────────────────────────────
/// A small pill-shaped badge encoding the [TransactionStatus] with semantic colours.
///
/// Adapts label color for dark/light mode — the background uses soft opacity so
/// it reads cleanly against both the card surface and the theme background.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TransactionStatus status;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (label, bgColor, fgColor) = switch (status) {
      TransactionStatus.pending => (
        'Pending',
        isDark ? Colors.orange.withAlpha(45) : Colors.orange.shade50,
        isDark ? Colors.orange.shade300 : Colors.orange.shade800,
      ),
      TransactionStatus.accepted => (
        'Accepted',
        isDark ? Colors.green.withAlpha(45) : Colors.green.shade50,
        isDark ? Colors.green.shade300 : Colors.green.shade800,
      ),
      TransactionStatus.rejected => (
        'Rejected',
        isDark ? Colors.red.withAlpha(45) : Colors.red.shade50,
        isDark ? Colors.red.shade300 : Colors.red.shade800,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fgColor.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fgColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// [TransactionType.payback], or [TransactionType.netSettlement].
///
/// For [TransactionType.debit]:
/// - Lender (requestedBy)     → Arrow Up   + "Lended"   (money left my pocket)
/// - Borrower (requestedFrom) → Arrow Down + "Borrowed" (money came to me)
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    required this.currentUserUid,
    required this.requestedByUid,
  });

  final TransactionType type;
  final String currentUserUid;
  final String requestedByUid;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;

    final (label, icon) = switch (type) {
      TransactionType.debit => currentUserUid == requestedByUid
          ? ('Borrowed', Icons.arrow_downward_rounded) // Borrower: money in
          : ('Lended', Icons.arrow_upward_rounded),    // Lender: money out
      TransactionType.payback       => ('Payback', Icons.arrow_downward_rounded),
      TransactionType.netSettlement => ('Settlement', Icons.handshake_rounded),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: outline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
