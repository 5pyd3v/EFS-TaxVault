import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/constants/app_constants.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';
import 'package:fbr_taxvault/features/invoices/presentation/invoice_review_providers.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';

class InvoiceReviewScreen extends ConsumerStatefulWidget {
  const InvoiceReviewScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  ConsumerState<InvoiceReviewScreen> createState() => _InvoiceReviewScreenState();
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

    setState(() => _isSaving = true);
    final result = await ref.read(invoiceRepositoryProvider).confirmVerification(
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
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Invoice saved to your vault.')));
        context.go(AppRoutes.home);
      },
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

    return Scaffold(
      appBar: AppBar(title: const Text('Review Invoice')),
      body: AsyncValueView<InvoiceDetail>(
        value: detailAsync,
        onRetry: () => ref.invalidate(invoiceDetailProvider(widget.invoiceId)),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.giant),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (detail.calculationMismatch) _WarningBanner(
              color: semantic.warning,
              container: semantic.warningContainer,
              message: 'Potential calculation mismatch. Please verify.',
            ),
            for (final warning in detail.warnings) ...[
              const SizedBox(height: AppSpacing.sm),
              _WarningBanner(
                color: warning.severity == 'error' ? theme.colorScheme.error : semantic.warning,
                container: warning.severity == 'error'
                    ? theme.colorScheme.errorContainer
                    : semantic.warningContainer,
                message: warning.message,
              ),
            ],
            const SizedBox(height: AppSpacing.xxl),
            Text('Supplier', style: theme.textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(
              detail.supplierName.isEmpty ? 'Not detected' : detail.supplierName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _FieldWithConfidence(
              label: 'Invoice number',
              controller: invoiceNumber,
              confidence: detail.confidenceFor('invoiceNumber'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _FieldWithConfidence(
              label: 'Invoice date (YYYY-MM-DD)',
              controller: invoiceDate,
              confidence: detail.confidenceFor('invoiceDate'),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('Amounts (PKR)', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _AmountField(label: 'Subtotal', controller: subtotal)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _AmountField(label: 'Discount', controller: discount)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _AmountField(label: 'Sales tax', controller: salesTax)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _AmountField(label: 'Other taxes', controller: otherTaxes)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _FieldWithConfidence(
              label: 'Total amount',
              controller: totalAmount,
              confidence: detail.confidenceFor('totalAmount'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            if (detail.items.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxxl),
              Text('Line items', style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.md),
              ...detail.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.description, style: theme.textTheme.bodyMedium)),
                        Text(
                          item.totalAmount.toStringAsFixed(2),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )),
            ],
            const SizedBox(height: AppSpacing.xxxl),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : onConfirm,
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Confirm & Save'),
              ),
            ),
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
  });

  final String label;
  final TextEditingController controller;
  final double confidence;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final needsReview = confidence < AppConstants.aiConfidenceReviewThreshold;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: needsReview
            ? Tooltip(
                message: 'Low-confidence extraction — please verify',
                child: Icon(Icons.info_outline_rounded, color: semantic.warning, size: 20),
              )
            : null,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.color, required this.container, required this.message});

  final Color color;
  final Color container;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: container, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
