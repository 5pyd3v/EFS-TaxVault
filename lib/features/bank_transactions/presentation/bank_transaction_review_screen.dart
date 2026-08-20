import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_detail.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';
import 'package:fbr_taxvault/features/documents/presentation/document_viewer_screen.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';
import 'package:fbr_taxvault/shared/providers/invoice_mutation_effects.dart';
import 'package:fbr_taxvault/shared/utils/amount_parsing.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';

class BankTransactionReviewScreen extends ConsumerStatefulWidget {
  const BankTransactionReviewScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  ConsumerState<BankTransactionReviewScreen> createState() =>
      _BankTransactionReviewScreenState();
}

class _BankTransactionReviewScreenState
    extends ConsumerState<BankTransactionReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _transactionDate = TextEditingController();
  final _counterpartyName = TextEditingController();
  final _counterpartyAccount = TextEditingController();
  final _bankName = TextEditingController();
  final _referenceNumber = TextEditingController();
  final _status = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  String _direction = 'debit';

  void _initFromDetail(BankTransactionDetail detail) {
    if (_initialized) return;
    _initialized = true;
    _direction = detail.direction;
    _amount.text = detail.amount.toStringAsFixed(2);
    _transactionDate.text = detail.transactionDate;
    _counterpartyName.text = detail.counterpartyName;
    _counterpartyAccount.text = detail.counterpartyAccount;
    _bankName.text = detail.bankName;
    _referenceNumber.text = detail.referenceNumber;
    _status.text = detail.status;
  }

  @override
  void dispose() {
    _amount.dispose();
    _transactionDate.dispose();
    _counterpartyName.dispose();
    _counterpartyAccount.dispose();
    _bankName.dispose();
    _referenceNumber.dispose();
    _status.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .saveDraftEdits(
          transactionId: widget.transactionId,
          direction: _direction,
          amount: parseAmount(_amount.text),
          transactionDate: _transactionDate.text.trim(),
          counterpartyName: _counterpartyName.text.trim(),
          counterpartyAccount: _counterpartyAccount.text.trim(),
          bankName: _bankName.text.trim(),
          referenceNumber: _referenceNumber.text.trim(),
          status: _status.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      (_) {
        ref.invalidate(bankTransactionDetailProvider(widget.transactionId));
        refreshBankTransactionDependentState(ref);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Changes saved.')));
        ref.read(selectedVaultViewProvider.notifier).state =
            VaultView.bankTransactions;
        context.go(AppRoutes.vault);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _confirmDispute() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dispute this transaction?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The submitter will be notified and can rescan it. You can add a reason (optional).',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Dispute'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _dispute(reasonController.text);
  }

  Future<void> _dispute(String reason) async {
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .rejectVerification(
          transactionId: widget.transactionId,
          reason: reason,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      (_) {
        ref.invalidate(bankTransactionDetailProvider(widget.transactionId));
        refreshBankTransactionDependentState(ref);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Transaction disputed.')),
          );
        ref.read(selectedVaultViewProvider.notifier).state =
            VaultView.bankTransactions;
        context.go(AppRoutes.vault);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _confirmRescan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rescan this transaction?'),
        content: const Text(
          'This deletes the current scan so you can capture a fresh photo. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rescan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    HapticFeedback.lightImpact();
    setState(() => _isDeleting = true);
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .deleteTransaction(widget.transactionId);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    result.fold(
      (_) {
        ref.invalidate(bankTransactionDetailProvider(widget.transactionId));
        refreshBankTransactionDependentState(ref);
        context.go(AppRoutes.scan);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _deleteTransaction() async {
    HapticFeedback.lightImpact();
    setState(() => _isDeleting = true);
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .deleteTransaction(widget.transactionId);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    result.fold(
      (_) {
        ref.invalidate(bankTransactionDetailProvider(widget.transactionId));
        refreshBankTransactionDependentState(ref);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Transaction deleted.')));
        ref.read(selectedVaultViewProvider.notifier).state =
            VaultView.bankTransactions;
        context.go(AppRoutes.vault);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  void _viewOriginalDocument(BankTransactionDetail detail) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DocumentViewerScreen(
          storagePath: detail.documentStoragePath!,
          pageCount: detail.documentPageCount,
          title: 'Original receipt',
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This permanently removes the transaction and its scanned pages. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteTransaction();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      bankTransactionDetailProvider(widget.transactionId),
    );
    final isApprover = ref.watch(isApproverProvider);

    // A scan is accepted and saved the moment extraction succeeds — there's
    // no "unconfirmed draft" state left to lose by navigating away, so
    // unlike the old approve-gated flow, back-press just leaves normally.
    // Rescan/Dispute/the explicit trash-icon delete are the only ways data
    // ever goes away now, each requiring its own deliberate confirmation.
    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Transaction'),
          actions: [
            if (detailAsync.valueOrNull?.hasScannedDocument ?? false)
              IconButton(
                icon: const Icon(Icons.image_outlined),
                tooltip: 'View original scan',
                onPressed: () => _viewOriginalDocument(detailAsync.value!),
              ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete transaction',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
          ],
        ),
        body: AsyncValueView<BankTransactionDetail>(
          value: detailAsync,
          onRetry: () => ref.invalidate(
            bankTransactionDetailProvider(widget.transactionId),
          ),
          data: (detail) {
            _initFromDetail(detail);
            return _ReviewForm(
              formKey: _formKey,
              detail: detail,
              direction: _direction,
              onDirectionChanged:
                  detail.verificationStatus == 'rejected' ||
                      detail.verificationStatus == 'verified'
                  ? null
                  : (value) => setState(() => _direction = value),
              amount: _amount,
              transactionDate: _transactionDate,
              counterpartyName: _counterpartyName,
              counterpartyAccount: _counterpartyAccount,
              bankName: _bankName,
              referenceNumber: _referenceNumber,
              status: _status,
              isSaving: _isSaving || _isDeleting,
              isApprover: isApprover,
              onSaveDraft: _saveDraft,
              onDispute: _confirmDispute,
              onRescan: _confirmRescan,
            );
          },
        ),
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.formKey,
    required this.detail,
    required this.direction,
    required this.onDirectionChanged,
    required this.amount,
    required this.transactionDate,
    required this.counterpartyName,
    required this.counterpartyAccount,
    required this.bankName,
    required this.referenceNumber,
    required this.status,
    required this.isSaving,
    required this.isApprover,
    required this.onSaveDraft,
    required this.onDispute,
    required this.onRescan,
  });

  final GlobalKey<FormState> formKey;
  final BankTransactionDetail detail;
  final String direction;
  final ValueChanged<String>? onDirectionChanged;
  final TextEditingController amount;
  final TextEditingController transactionDate;
  final TextEditingController counterpartyName;
  final TextEditingController counterpartyAccount;
  final TextEditingController bankName;
  final TextEditingController referenceNumber;
  final TextEditingController status;
  final bool isSaving;
  final bool isApprover;
  final VoidCallback onSaveDraft;
  final VoidCallback onDispute;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = detail.verificationStatus == 'verified';
    final isRejected = detail.verificationStatus == 'rejected';
    final enabled = !isVerified && !isRejected;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.xxl,
        AppSpacing.giant,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Transaction', style: theme.textTheme.headlineSmall),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'debit', label: Text('Debit')),
                  ButtonSegment(value: 'credit', label: Text('Credit')),
                ],
                selected: {direction},
                onSelectionChanged: onDirectionChanged == null
                    ? null
                    : (selection) => onDirectionChanged!(selection.first),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: amount,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (${detail.currency})',
                suffixIcon:
                    detail.confidenceFor('amount') <
                            AppConstants.aiConfidenceReviewThreshold &&
                        enabled
                    ? Tooltip(
                        message: 'Low-confidence extraction — please verify',
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: transactionDate,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Date/time (YYYY-MM-DD or ISO 8601)',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: counterpartyName,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(labelText: 'Counterparty name'),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: counterpartyAccount,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Counterparty account / IBAN',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: bankName,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Bank / wallet name',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: referenceNumber,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(
                labelText: 'Reference / transaction ID',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: status,
              enabled: enabled,
              style: theme.textTheme.titleMedium,
              decoration: const InputDecoration(labelText: 'Status'),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            if (isVerified)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'This transaction has been verified and saved',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              )
            else if (isRejected) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cancel_rounded,
                          color: theme.colorScheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'This transaction was disputed',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                    if (detail.rejectionReason?.trim().isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        detail.rejectionReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isSaving ? null : onRescan,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Rescan'),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onSaveDraft,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save changes'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: isSaving ? null : onRescan,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Rescan'),
                ),
              ),
              if (isApprover) ...[
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: isSaving ? null : onDispute,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    child: const Text('Dispute'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
