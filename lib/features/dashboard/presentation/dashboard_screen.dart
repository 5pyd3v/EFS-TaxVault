import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/section_header.dart';
import 'package:fbr_taxvault/shared/widgets/stat_tile.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'PKR ', decimalDigits: 0);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back', style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              )),
              const SizedBox(height: 2),
              Text(user?.displayName ?? '', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.scan),
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Scan Invoice'),
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl),
              AsyncValueView<DashboardSummary>(
                value: summaryAsync,
                onRetry: () => ref.invalidate(dashboardSummaryProvider),
                loading: (_) => const _StatsSkeleton(),
                data: (summary) => _DashboardContent(summary: summary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Total invoices',
                      value: '${summary.totalInvoices}',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'This month',
                      value: '${summary.currentMonthInvoices}',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Tax this month',
                      value: _currencyFormat.format(summary.currentMonthTaxAmount),
                      icon: Icons.account_balance_outlined,
                    ),
                  ),
                  Expanded(
                    child: StatTile(
                      label: 'Pending verification',
                      value: '${summary.pendingVerification}',
                      icon: Icons.fact_check_outlined,
                      valueColor: summary.pendingVerification > 0 ? semantic.warning : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (summary.potentialIssues > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: semantic.warningContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: semantic.warning, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${summary.potentialIssues} invoice(s) need attention — please verify.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xxxl),
        SectionHeader(
          title: 'Recent invoices',
          actionLabel: summary.totalInvoices == 0 ? null : 'See all',
          onAction: summary.totalInvoices == 0 ? null : () => context.go(AppRoutes.vault),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (summary.totalInvoices == 0)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: 'No invoices yet',
              message: 'Scan your first invoice and TaxVault will organize the rest.',
            ),
          )
        else
          const _RecentInvoicesList(),
      ],
    );
  }
}

class _RecentInvoicesList extends ConsumerWidget {
  const _RecentInvoicesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentInvoicesProvider);
    final theme = Theme.of(context);

    return AsyncValueView<List<InvoiceSummary>>(
      value: recentAsync,
      loading: (_) => const SizedBox.shrink(),
      data: (invoices) => Column(
        children: [
          for (final invoice in invoices)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          invoice.supplierName,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _currencyFormat.format(invoice.totalAmount),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
