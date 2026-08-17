import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_extraction_outcome.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);

/// Shown right after a bank-receipt document uploads, while
/// `extract-bank-transaction` runs — same shape as the invoice
/// `ProcessingScreen`, a single honest "analyzing" state.
class BankTransactionProcessingScreen extends ConsumerStatefulWidget {
  const BankTransactionProcessingScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<BankTransactionProcessingScreen> createState() =>
      _BankTransactionProcessingScreenState();
}

class _BankTransactionProcessingScreenState
    extends ConsumerState<BankTransactionProcessingScreen> {
  bool _isSavingAnyway = false;
  String? _saveAnywayError;

  Future<void> _saveAnyway() async {
    setState(() {
      _isSavingAnyway = true;
      _saveAnywayError = null;
    });
    final result = await ref
        .read(bankTransactionAiRepositoryProvider)
        .extractBankTransaction(widget.documentId, force: true);

    if (!mounted) return;
    result.fold(
      (outcome) {
        if (outcome is BankTransactionExtractionSuccess) {
          context.pushReplacement(
            AppRoutes.bankTransactionReview(outcome.transactionId),
          );
        } else {
          setState(() {
            _isSavingAnyway = false;
            _saveAnywayError =
                'Could not save this transaction. Please try again.';
          });
        }
      },
      (failure) => setState(() {
        _isSavingAnyway = false;
        _saveAnywayError = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extraction = ref.watch(_extractionProvider(widget.documentId));

    ref.listen(_extractionProvider(widget.documentId), (previous, next) {
      final outcome = next.valueOrNull;
      if (outcome is BankTransactionExtractionSuccess) {
        context.pushReplacement(
          AppRoutes.bankTransactionReview(outcome.transactionId),
        );
      }
    });

    return PopScope(
      canPop: !extraction.isLoading && !_isSavingAnyway,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analyzing'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Center(
            child: extraction.when(
              data: (outcome) => switch (outcome) {
                BankTransactionExtractionSuccess() =>
                  const CircularProgressIndicator(),
                BankTransactionExtractionDuplicate() => _DuplicatePrompt(
                  outcome: outcome,
                  isSaving: _isSavingAnyway,
                  error: _saveAnywayError,
                  onViewExisting: () => context.pushReplacement(
                    AppRoutes.bankTransactionReview(
                      outcome.existingTransactionId,
                    ),
                  ),
                  onSaveAnyway: _saveAnyway,
                ),
                BankTransactionExtractionKeyError() => _KeyErrorPrompt(
                  outcome: outcome,
                ),
              },
              loading: () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Reading your receipt',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Extracting the amount, date, and account details — this can take a few seconds.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              error: (error, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text('Analysis failed', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$error\n\nThe document itself was saved — you can try again.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  ElevatedButton(
                    onPressed: () =>
                        ref.invalidate(_extractionProvider(widget.documentId)),
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final _extractionProvider =
    FutureProvider.family<BankTransactionExtractionOutcome, String>((
      ref,
      documentId,
    ) async {
      final result = await ref
          .watch(bankTransactionAiRepositoryProvider)
          .extractBankTransaction(documentId);
      return result.fold((outcome) => outcome, (failure) => throw failure);
    });

/// Shown when the org's Gemini key is missing/exhausted/invalid — mirrors
/// the invoice processing screen's `_KeyErrorPrompt`.
class _KeyErrorPrompt extends StatelessWidget {
  const _KeyErrorPrompt({required this.outcome});

  final BankTransactionExtractionKeyError outcome;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.key_off_outlined,
          size: 40,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('API key needs attention', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          outcome.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.push(AppRoutes.aiKeySettings),
            child: const Text('Update API Key'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to Home'),
        ),
      ],
    );
  }
}

class _DuplicatePrompt extends StatelessWidget {
  const _DuplicatePrompt({
    required this.outcome,
    required this.isSaving,
    required this.error,
    required this.onViewExisting,
    required this.onSaveAnyway,
  });

  final BankTransactionExtractionDuplicate outcome;
  final bool isSaving;
  final String? error;
  final VoidCallback onViewExisting;
  final VoidCallback onSaveAnyway;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.content_copy_rounded,
          size: 36,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('Possible duplicate', style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Text(
          outcome.existingReferenceNumber != null
              ? 'This looks like a transaction (ref #${outcome.existingReferenceNumber}) you already saved'
                    '${outcome.existingAmount != null ? ' (${_currencyFormat.format(outcome.existingAmount)})' : ''}.'
              : 'This looks like a receipt you already saved.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (error != null) ...[
          Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: AppSpacing.lg),
        ],
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: isSaving ? null : onViewExisting,
            child: const Text('View existing transaction'),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isSaving ? null : onSaveAnyway,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save anyway'),
          ),
        ),
      ],
    );
  }
}
