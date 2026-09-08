import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../features/auth/providers/auth_providers.dart';
import '../../friends/providers/friends_providers.dart';
import '../models/transaction_model.dart';
import '../providers/ledger_providers.dart';

// ── CreateDebitView ────────────────────────────────────────────────────────────
/// A form for creating a new debit request.
///
/// Converts a decimal string amount into integer cents.
/// Looks up the counterparty UID by email.
/// Constructs a [TransactionModel] and submits it to [LedgerRepository].
class CreateDebitView extends ConsumerStatefulWidget {
  const CreateDebitView({super.key, this.initialEmail});

  final String? initialEmail;
  @override
  ConsumerState<CreateDebitView> createState() => _CreateDebitViewState();
}

class _CreateDebitViewState extends ConsumerState<CreateDebitView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  TextEditingController? _autocompleteEmailController;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentAppUserProvider).valueOrNull;
    if (currentUser == null) return;
    setState(() => _isLoading = true);
    try {
      // 1. Resolve counterparty UID
      final email = _autocompleteEmailController?.text.trim() ?? '';
      final authRepo = ref.read(authRepositoryProvider);

      final counterpartyUid = await authRepo.findUidByEmail(email);

      if (counterpartyUid == null) {
        throw Exception('No user found with email: $email');
      }

      if (counterpartyUid == currentUser.uid) {
        throw Exception('You cannot send a request to yourself.');
      }
      // 2. Parse amount to integer cents
      final amountString = _amountController.text.trim();
      final amountDouble = double.parse(amountString);
      final amountCents = (amountDouble * 100).round();

      if (amountCents <= 0) {
        throw Exception('Amount must be greater than zero.');
      }
      // 3. Construct transaction model
      final tx = TransactionModel(
        id: const Uuid().v4(),
        type: TransactionType.debit,
        status: TransactionStatus.pending,
        amount: amountCents,
        remainingAmount: amountCents, // Initial remaining is full amount
        requestedBy: currentUser.uid,
        requestedFrom: counterpartyUid,
        createdAt: DateTime.now(),
        notes: _notesController.text.trim(),
      );
      // 4. Submit to repository
      await ref.read(ledgerRepositoryProvider).createDebitRequest(
        tx,
        actorName: currentUser.name,
      );
      if (mounted) {
        context.pop(); // Return to Ledger View
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Debit request sent!')));
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

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('New Request')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Amount Input
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      enabled: !_isLoading,
                      textAlign: TextAlign.center,
                      style: tt.displayMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '0.00',
                        prefixText: 'ETB ',
                        prefixStyle: tt.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty)
                          return 'Enter amount';
                        final val = double.tryParse(value);
                        if (val == null || val <= 0) return 'Invalid amount';
                        return null;
                      },
                    ),

                    const SizedBox(height: 48),

                    // Counterparty Email Input
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: widget.initialEmail ?? ''),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final currentUser = ref.read(currentAppUserProvider).valueOrNull;
                        if (currentUser == null) return const Iterable<String>.empty();
                        
                        final recents = ref.read(recentsStreamProvider(currentUser.uid)).valueOrNull ?? [];
                        return recents
                            .map((r) => r.email)
                            .where((email) => email.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                        _autocompleteEmailController = textEditingController;
                        return TextFormField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: "Friend's Email",
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty)
                              return 'Enter an email';
                            if (!value.contains('@')) return 'Invalid email';
                            return null;
                          },
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Notes Input
                    TextFormField(
                      controller: _notesController,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.notes),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),

              // Submit Button
              Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          'Send Request',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
