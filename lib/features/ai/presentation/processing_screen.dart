import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/ai/presentation/ai_processing_providers.dart';

/// Shown right after a document uploads, while the `extract-invoice` Edge
/// Function runs. Deliberately a single honest "analyzing" state rather
/// than a scripted sequence of fake sub-steps (spec §13) — the Edge
/// Function is one blocking call with no intermediate progress to report,
/// so pretending otherwise would be lying about what's actually happening.
class ProcessingScreen extends ConsumerWidget {
  const ProcessingScreen({super.key, required this.documentId});

  final String documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extraction = ref.watch(aiExtractionProvider(documentId));

    ref.listen(aiExtractionProvider(documentId), (previous, next) {
      next.whenData((invoiceId) {
        context.pushReplacement(AppRoutes.invoiceReview(invoiceId));
      });
    });

    return PopScope(
      canPop: !extraction.isLoading,
      child: Scaffold(
        appBar: AppBar(title: const Text('Analyzing'), automaticallyImplyLeading: false),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Center(
            child: extraction.when(
              data: (_) => const CircularProgressIndicator(),
              loading: () => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.xxl),
                  Text('Analyzing your invoice', style: theme.textTheme.titleMedium),
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
                  Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
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
                    onPressed: () => ref.invalidate(aiExtractionProvider(documentId)),
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
