import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_providers.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';

class PaybackModal extends ConsumerStatefulWidget {
  const PaybackModal({
    super.key,
    required this.debit,
    required this.currentUserUid,
  });
  final TransactionModel debit;
  final String currentUserUid;
  @override
  ConsumerState<PaybackModal> createState() => _PaybackModalState();
}

class _PaybackModalState extends ConsumerState<PaybackModal> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isLoading = false;
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final amountString = _amountController.text.trim();
      final amountDouble = double.parse(amountString);
      final amountCents = (amountDouble * 100).round();
      if (amountCents <= 0) {
        throw Exception('Amount must be greater than zero.');
      }
      if (amountCents > widget.debit.remainingAmount) {
        throw Exception('Cannot pay back more than the remaining balance.');
      }
      final paybackTx = TransactionModel(
        id: const Uuid().v4(),
        type: TransactionType.payback,
        status: TransactionStatus.pending,
        linkedDebitId: widget.debit.id,
        requestedBy: widget.currentUserUid,
        requestedFrom: widget.debit.requestedBy, // The original lender
        amount: amountCents,
        remainingAmount: 0, // Paybacks don't have remaining amounts
        createdAt: DateTime.now(),
      );
      await ref.read(ledgerRepositoryProvider).createPaybackRequest(
        paybackTx,
        actorName:
            ref.read(currentAppUserProvider).valueOrNull?.name ?? 'Someone',
      );
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payback request sent!')));
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
    final remainingFormatted =
        '\$${(widget.debit.remainingAmount / 100).toStringAsFixed(2)}';
    return Padding(
      // Ensure padding accounts for keyboard if modal is set to isScrollControlled
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pay Back',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Remaining Balance: $remainingFormatted',
              style: tt.bodyMedium?.copyWith(color: cs.outline),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              enabled: !_isLoading,
              textAlign: TextAlign.center,
              style: tt.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: '0.00',
                prefixText: '\$',
                prefixStyle: tt.headlineMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter amount';
                final val = double.tryParse(value);
                if (val == null || val <= 0) return 'Invalid amount';
                final cents = (val * 100).round();
                if (cents > widget.debit.remainingAmount) {
                  return 'Cannot exceed $remainingFormatted';
                }
                return null;
              },
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
                      'Send Payback Request',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
