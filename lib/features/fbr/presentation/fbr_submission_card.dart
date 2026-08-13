import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submission.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submit_outcome.dart';
import 'package:fbr_taxvault/features/fbr/presentation/fbr_providers.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';

final _dateFormat = DateFormat('d MMM yyyy, h:mm a');

/// Embedded in the Invoice Review screen once an invoice is verified.
/// Everything here is explicitly labeled mock/simulated — there is no real
/// FBR API integration yet (spec §5-6, §34), only the adapter architecture
/// that will host one.
class FbrSubmissionCard extends ConsumerStatefulWidget {
  const FbrSubmissionCard({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<FbrSubmissionCard> createState() => _FbrSubmissionCardState();
}

class _FbrSubmissionCardState extends ConsumerState<FbrSubmissionCard> {
  bool _isSubmitting = false;
  List<String>? _validationErrors;

  Future<void> _submit() async {
    HapticFeedback.lightImpact();
    setState(() {
      _isSubmitting = true;
      _validationErrors = null;
    });

    final result = await ref
        .read(fbrRepositoryProvider)
        .submit(widget.invoiceId);
    if (!mounted) return;

    result.fold(
      (outcome) {
        setState(() => _isSubmitting = false);
        switch (outcome) {
          case FbrSubmitAccepted():
          case FbrSubmitAlreadySubmitted():
            ref.invalidate(fbrSubmissionProvider(widget.invoiceId));
          case FbrSubmitValidationFailed(:final errors):
            setState(() => _validationErrors = errors);
        }
      },
      (failure) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submissionAsync = ref.watch(fbrSubmissionProvider(widget.invoiceId));

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('FBR submission', style: theme.textTheme.titleSmall),
              const Spacer(),
              submissionAsync.maybeWhen(
                data: (submission) => submission != null
                    ? _StatusBadge(status: submission.status)
                    : const SizedBox.shrink(),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          submissionAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => Text(
              'Could not load submission status.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            data: (submission) => _buildBody(theme, submission),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, FbrSubmission? submission) {
    if (submission != null &&
        submission.status == FbrSubmissionStatus.accepted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference: ${submission.externalReference ?? '—'}',
            style: theme.textTheme.bodyMedium,
          ),
          if (submission.submittedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              _dateFormat.format(submission.submittedAt!.toLocal()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Simulated acceptance — FBR API integration is not yet connected. This is not a real filing.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Not yet submitted. The FBR e-invoicing API isn\'t available yet — this runs the '
          'full validation pipeline against a mock adapter so it\'s ready to switch over.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_validationErrors != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final error in _validationErrors!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '• $error',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _submit,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 18),
            label: Text(_isSubmitting ? 'Submitting…' : 'Submit to FBR (mock)'),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final FbrSubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (color, container, label) = switch (status) {
      FbrSubmissionStatus.accepted => (
        semantic.success,
        semantic.successContainer,
        'Accepted',
      ),
      FbrSubmissionStatus.submitted || FbrSubmissionStatus.queued => (
        semantic.info,
        semantic.infoContainer,
        'Pending',
      ),
      FbrSubmissionStatus.rejected || FbrSubmissionStatus.failed => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer,
        'Failed',
      ),
      FbrSubmissionStatus.retryRequired => (
        semantic.warning,
        semantic.warningContainer,
        'Retry needed',
      ),
      FbrSubmissionStatus.notReady || FbrSubmissionStatus.ready => (
        theme.colorScheme.onSurfaceVariant,
        theme.colorScheme.surfaceContainerHighest,
        'Not submitted',
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
