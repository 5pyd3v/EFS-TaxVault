import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/fbr/presentation/fbr_submission_card.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';
import 'package:fbr_taxvault/features/invoices/presentation/invoice_review_providers.dart';
import 'package:fbr_taxvault/shared/providers/invoice_mutation_effects.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 2,
);
final _qtyFormat = NumberFormat('#,##0.##');

class InvoiceReviewScreen extends ConsumerStatefulWidget {
  const InvoiceReviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceReviewScreen> createState() =>
      _InvoiceReviewScreenState();
}

class _InvoiceReviewScreenState extends ConsumerState<InvoiceReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumber = TextEditingController();
  final _invoiceDate = TextEditingController();
  final _subtotal = TextEditingController();
  final _discount = TextEditingController();
  final _salesTax = TextEditingController();
  final _otherTaxes = TextEditingController();
  final _totalAmount = TextEditingController();

  bool _initialized = false;
  bool _isSaving = false;
  bool _isDeleting = false;

  void _initFromDetail(InvoiceDetail detail) {
    if (_initialized) return;
    _initialized = true;
    _invoiceNumber.text = detail.invoiceNumber;
    _invoiceDate.text = detail.invoiceDate;
    _subtotal.text = detail.subtotal.toStringAsFixed(2);
    _discount.text = detail.discount.toStringAsFixed(2);
    _salesTax.text = detail.salesTax.toStringAsFixed(2);
    _otherTaxes.text = detail.otherTaxes.toStringAsFixed(2);
    _totalAmount.text = detail.totalAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _invoiceDate.dispose();
    _subtotal.dispose();
    _discount.dispose();
    _salesTax.dispose();
    _otherTaxes.dispose();
    _totalAmount.dispose();
    super.dispose();
  }

  Future<void> _confirmAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    final result = await ref
        .read(invoiceRepositoryProvider)
        .confirmVerification(
          invoiceId: widget.invoiceId,
          invoiceNumber: _invoiceNumber.text.trim(),
          invoiceDate: _invoiceDate.text.trim(),
          subtotal: double.tryParse(_subtotal.text) ?? 0,
          discount: double.tryParse(_discount.text) ?? 0,
          salesTax: double.tryParse(_salesTax.text) ?? 0,
          otherTaxes: double.tryParse(_otherTaxes.text) ?? 0,
          totalAmount: double.tryParse(_totalAmount.text) ?? 0,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      (_) {
        // Without this, revisiting this invoice would keep showing the
        // pre-confirm state — the detail provider is a plain (non-
        // autoDispose) FutureProvider.family, so it caches the response
        // forever unless explicitly invalidated after a mutation.
        ref.invalidate(invoiceDetailProvider(widget.invoiceId));
        refreshInvoiceDependentState(ref);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('Invoice saved to your vault.')),
          );
        context.go(AppRoutes.home);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _deleteInvoice() async {
    HapticFeedback.lightImpact();
    setState(() => _isDeleting = true);
    final result = await ref
        .read(invoiceRepositoryProvider)
        .deleteInvoice(widget.invoiceId);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    result.fold(
      (_) {
        ref.invalidate(invoiceDetailProvider(widget.invoiceId));
        refreshInvoiceDependentState(ref);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Invoice deleted.')));
        context.go(AppRoutes.vault);
      },
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: const Text(
          'This permanently removes the invoice and its scanned pages. This can\'t be undone.',
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
    if (confirmed == true) await _deleteInvoice();
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard this scan?'),
        content: const Text(
          'You haven\'t saved this invoice yet. Discard it, or keep reviewing?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep reviewing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _showCanonicalJson() async {
    final result = await ref
        .read(invoiceRepositoryProvider)
        .getCanonicalJson(widget.invoiceId);
    if (!mounted) return;

    result.fold(
      (json) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _CanonicalJsonSheet(json: json),
      ),
      (failure) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(invoiceDetailProvider(widget.invoiceId));
    final isVerified =
        detailAsync.valueOrNull?.verificationStatus == 'verified';

    return PopScope(
      canPop: isVerified || _isDeleting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard) await _deleteInvoice();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Review Invoice'),
          actions: [
            IconButton(
              icon: const Icon(Icons.data_object_rounded),
              tooltip: 'Export canonical JSON',
              onPressed: _showCanonicalJson,
            ),
            IconButton(
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded),
              tooltip: 'Delete invoice',
              onPressed: _isDeleting ? null : _confirmDelete,
            ),
          ],
        ),
        body: AsyncValueView<InvoiceDetail>(
          value: detailAsync,
          onRetry: () =>
              ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
          data: (detail) {
            _initFromDetail(detail);
            return _ReviewForm(
              formKey: _formKey,
              detail: detail,
              invoiceNumber: _invoiceNumber,
              invoiceDate: _invoiceDate,
              subtotal: _subtotal,
              discount: _discount,
              salesTax: _salesTax,
              otherTaxes: _otherTaxes,
              totalAmount: _totalAmount,
              isSaving: _isSaving,
              onConfirm: _confirmAndSave,
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
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.subtotal,
    required this.discount,
    required this.salesTax,
    required this.otherTaxes,
    required this.totalAmount,
    required this.isSaving,
    required this.onConfirm,
  });

  final GlobalKey<FormState> formKey;
  final InvoiceDetail detail;
  final TextEditingController invoiceNumber;
  final TextEditingController invoiceDate;
  final TextEditingController subtotal;
  final TextEditingController discount;
  final TextEditingController salesTax;
  final TextEditingController otherTaxes;
  final TextEditingController totalAmount;
  final bool isSaving;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final isVerified = detail.verificationStatus == 'verified';

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
            if (detail.calculationMismatch)
              _WarningBanner(
                color: semantic.warning,
                container: semantic.warningContainer,
                message: 'Potential calculation mismatch. Please verify.',
              ),
            for (final warning in detail.warnings) ...[
              const SizedBox(height: AppSpacing.sm),
              _WarningBanner(
                color: warning.severity == 'error'
                    ? theme.colorScheme.error
                    : semantic.warning,
                container: warning.severity == 'error'
                    ? theme.colorScheme.errorContainer
                    : semantic.warningContainer,
                message: warning.message,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Supplier', style: theme.textTheme.labelMedium),
                      const SizedBox(height: 2),
                      Text(
                        detail.supplierName.isEmpty
                            ? 'Not detected'
                            : detail.supplierName,
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (isVerified)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: semantic.successContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: semantic.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: semantic.success,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            _FieldWithConfidence(
              label: 'Invoice number',
              controller: invoiceNumber,
              confidence: detail.confidenceFor('invoiceNumber'),
              enabled: !isVerified,
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldWithConfidence(
              label: 'Invoice date (YYYY-MM-DD)',
              controller: invoiceDate,
              confidence: detail.confidenceFor('invoiceDate'),
              enabled: !isVerified,
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Amounts (PKR)', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    label: 'Subtotal',
                    controller: subtotal,
                    enabled: !isVerified,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _AmountField(
                    label: 'Discount',
                    controller: discount,
                    enabled: !isVerified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _AmountField(
                    label: 'Sales tax',
                    controller: salesTax,
                    enabled: !isVerified,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _AmountField(
                    label: 'Other taxes',
                    controller: otherTaxes,
                    enabled: !isVerified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldWithConfidence(
              label: 'Total amount',
              controller: totalAmount,
              confidence: detail.confidenceFor('totalAmount'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !isVerified,
            ),
            if (detail.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxxl),
              Text('Line items', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.md),
              ...detail.items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _LineItemCard(item: item),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxxl),
            if (isVerified)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: semantic.successContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: semantic.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'This invoice has been verified and saved',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: semantic.success,
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSaving ? null : onConfirm,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm & Save'),
                ),
              ),
            if (isVerified) ...[
              const SizedBox(height: AppSpacing.lg),
              FbrSubmissionCard(invoiceId: detail.id),
            ],
          ],
        ),
      ),
    );
  }
}

class _FieldWithConfidence extends StatelessWidget {
  const _FieldWithConfidence({
    required this.label,
    required this.controller,
    required this.confidence,
    this.keyboardType,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final double confidence;
  final TextInputType? keyboardType;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final needsReview =
        enabled && confidence < AppConstants.aiConfidenceReviewThreshold;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      // Entered/extracted values are data the user is verifying, not a
      // placeholder — force full-contrast bold text rather than whatever
      // Flutter's TextField falls back to when no style is given.
      style: theme.textTheme.titleMedium?.copyWith(
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: needsReview
            ? Tooltip(
                message: 'Low-confidence extraction — please verify',
                child: Icon(
                  Icons.info_outline_rounded,
                  color: semantic.warning,
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: enabled,
      style: theme.textTheme.titleMedium?.copyWith(
        color: enabled
            ? theme.colorScheme.onSurface
            : theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _LineItemCard extends StatelessWidget {
  const _LineItemCard({required this.item});

  final InvoiceItemLine item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuantity = item.quantity > 0 && item.unitPrice > 0;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: Icons.shopping_bag_outlined,
            colorKey: item.description,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description.isEmpty ? 'Item' : item.description,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  hasQuantity
                      ? '${_qtyFormat.format(item.quantity)} × ${_currencyFormat.format(item.unitPrice)}'
                      : 'Qty not detected',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (item.taxAmount > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tax ${_currencyFormat.format(item.taxAmount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _currencyFormat.format(item.totalAmount),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({
    required this.color,
    required this.container,
    required this.message,
  });

  final Color color;
  final Color container;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _CanonicalJsonSheet extends StatelessWidget {
  const _CanonicalJsonSheet({required this.json});

  final Map<String, dynamic> json;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pretty = const JsonEncoder.withIndent('  ').convert(json);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            0,
            AppSpacing.xxl,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Canonical invoice JSON',
                    style: theme.textTheme.titleMedium,
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: pretty));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                    },
                  ),
                ],
              ),
              Text(
                'Internal schema version ${json['schemaVersion']} — not yet an official FBR '
                'payload; this is what an FBR adapter will map from once integrated.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      pretty,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
