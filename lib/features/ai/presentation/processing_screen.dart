import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/ai/domain/extraction_outcome.dart';
import 'package:fbr_taxvault/features/ai/presentation/ai_processing_providers.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);

/// Shown right after a document uploads, while the `extract-invoice` Edge
/// Function runs. Deliberately a single honest "analyzing" state rather
/// than a scripted sequence of fake sub-steps (spec §13) — the Edge
/// Function is one blocking call with no intermediate progress to report,
/// so pretending otherwise would be lying about what's actually happening.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({super.key, required this.documentId});

  final String documentId;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  bool _isSavingAnyway = false;
  String? _saveAnywayError;

  Future<void> _saveAnyway() async {
    setState(() {
      _isSavingAnyway = true;
      _saveAnywayError = null;
    });
    final result = await ref
        .read(aiProcessingRepositoryProvider)
        .extractInvoice(widget.documentId, force: true);

    if (!mounted) return;
    result.fold(
      (outcome) {
        if (outcome is ExtractionSuccess) {
          context.pushReplacement(AppRoutes.invoiceReview(outcome.invoiceId));
        } else {
          setState(() {
            _isSavingAnyway = false;
            _saveAnywayError = 'Could not save this invoice. Please try again.';
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
    final extraction = ref.watch(aiExtractionProvider(widget.documentId));

    ref.listen(aiExtractionProvider(widget.documentId), (previous, next) {
      final outcome = next.valueOrNull;
      if (outcome is ExtractionSuccess) {
        context.pushReplacement(AppRoutes.invoiceReview(outcome.invoiceId));
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
                ExtractionSuccess() => const CircularProgressIndicator(),
                ExtractionDuplicate() => _DuplicatePrompt(
                  outcome: outcome,
                  isSaving: _isSavingAnyway,
                  error: _saveAnywayError,
                  onViewExisting: () => context.pushReplacement(
                    AppRoutes.invoiceReview(outcome.existingInvoiceId),
                  ),
                  onSaveAnyway: _saveAnyway,
                ),
              },
              loading: () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    'Analyzing your invoice',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Reading the document and checking the numbers — this can take a few seconds.',
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
                        ref.invalidate(aiExtractionProvider(widget.documentId)),
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

class _DuplicatePrompt extends StatelessWidget {
  const _DuplicatePrompt({
    required this.outcome,
    required this.isSaving,
    required this.error,
    required this.onViewExisting,
    required this.onSaveAnyway,
  });

  final ExtractionDuplicate outcome;
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
          outcome.existingInvoiceNumber != null
              ? 'This looks like invoice #${outcome.existingInvoiceNumber} you already saved'
                    '${outcome.existingTotalAmount != null ? ' (${_currencyFormat.format(outcome.existingTotalAmount)})' : ''}.'
              : 'This looks like a document you already saved to your vault.',
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
            child: const Text('View existing invoice'),
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
