import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';
import 'package:fbr_taxvault/features/reports/domain/counterparty_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/transaction_period_summary.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_providers.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_controller.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/app_segmented_toggle.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';
import 'package:fbr_taxvault/shared/widgets/list_skeleton.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);
final _dateFormat = DateFormat('d MMM yyyy');

String _periodLabel(PeriodType periodType, DateTime date) {
  return switch (periodType) {
    PeriodType.monthly => DateFormat('MMMM yyyy').format(date),
    PeriodType.quarterly => 'Q${((date.month - 1) ~/ 3) + 1} ${date.year}',
    PeriodType.annual => '${date.year}',
  };
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _searchController = TextEditingController();
  bool _isExporting = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportToExcel() async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null || _isExporting) return;
    final domain = ref.read(selectedReportDomainProvider);

    setState(() => _isExporting = true);
    final result = domain == ReportDomain.invoices
        ? await ref.read(reportExportServiceProvider).exportToExcel(organization.id)
        : await ref
              .read(bankTransactionExportServiceProvider)
              .exportToExcel(organization.id);

    if (!mounted) return;
    setState(() => _isExporting = false);

    result.fold(
      (file) {
        SharePlus.instance.share(
          ShareParams(
            files: [
              XFile(
                file.path,
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              ),
            ],
            subject: 'EFS TaxVault Report',
            text: 'Your EFS TaxVault report is attached.',
          ),
        );
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
    final domain = ref.watch(selectedReportDomainProvider);
    final view = ref.watch(selectedReportViewProvider);
    final query = ref.watch(reportsSearchQueryProvider);
    final isInvoices = domain == ReportDomain.invoices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            tooltip: 'Export to Excel',
            onPressed: _isExporting ? null : _exportToExcel,
          ),
          if (view == ReportView.byPeriod)
            PopupMenuButton<PeriodType>(
              initialValue: ref.watch(selectedPeriodTypeProvider),
              onSelected: (type) =>
                  ref.read(selectedPeriodTypeProvider.notifier).state = type,
              icon: const Icon(Icons.calendar_view_month_rounded),
              itemBuilder: (context) => PeriodType.values
                  .map(
                    (type) =>
                        PopupMenuItem(value: type, child: Text(type.label)),
                  )
                  .toList(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppSegmentedToggle<ReportDomain>(
              segments: const [
                AppToggleSegment(
                  value: ReportDomain.invoices,
                  label: 'Invoices',
                  icon: Icons.receipt_long_rounded,
                ),
                AppToggleSegment(
                  value: ReportDomain.bankTransactions,
                  label: 'Bank Transactions',
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ],
              selected: domain,
              onChanged: (value) =>
                  ref.read(selectedReportDomainProvider.notifier).state =
                      value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: AppTabToggle<ReportView>(
              segments: [
                const AppToggleSegment(
                  value: ReportView.byPeriod,
                  label: 'By period',
                  icon: Icons.calendar_view_month_rounded,
                ),
                AppToggleSegment(
                  value: ReportView.byGroup,
                  label: isInvoices ? 'By supplier' : 'By counterparty',
                  icon: isInvoices
                      ? Icons.storefront_rounded
                      : Icons.person_rounded,
                ),
              ],
              selected: view,
              onChanged: (value) =>
                  ref.read(selectedReportViewProvider.notifier).state = value,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(reportsSearchQueryProvider.notifier).state = value,
              decoration: InputDecoration(
                hintText: view == ReportView.byPeriod
                    ? 'Search periods, e.g. "January"'
                    : isInvoices
                    ? 'Search suppliers'
                    : 'Search counterparties',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(reportsSearchQueryProvider.notifier).state =
                              '';
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody(domain, view)),
        ],
      ),
    );
  }

  Widget _buildBody(ReportDomain domain, ReportView view) {
    if (domain == ReportDomain.invoices) {
      return view == ReportView.byPeriod
          ? const _ByPeriodView()
          : const _BySupplierView();
    }
    return view == ReportView.byPeriod
        ? const _TransactionsByPeriodView()
        : const _ByCounterpartyView();
  }
}

class _ByPeriodView extends ConsumerWidget {
  const _ByPeriodView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final summariesAsync = ref.watch(periodSummariesProvider);
    final query = ref.watch(reportsSearchQueryProvider).trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(periodSummariesProvider),
      child: AsyncValueView<List<PeriodSummary>>(
        value: summariesAsync,
        onRetry: () => ref.invalidate(periodSummariesProvider),
        loading: (_) => const ListSkeleton(),
        data: (allSummaries) {
          final summaries = query.isEmpty
              ? allSummaries
              : allSummaries
                    .where(
                      (s) => _periodLabel(
                        periodType,
                        s.periodStart,
                      ).toLowerCase().contains(query),
                    )
                    .toList();

          if (allSummaries.isEmpty) {
            return const _ReportsEmptyState(
              message:
                  'Once you have invoices in your vault, tax reports will appear here.',
            );
          }
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryTiles(
                  countIcon: Icons.receipt_long_rounded,
                  countLabel:
                      '${summaries.fold<int>(0, (a, s) => a + s.invoiceCount)}',
                  countSuffix: 'invoices',
                  stat1Icon: Icons.shopping_bag_outlined,
                  stat1Label: 'Purchases',
                  stat1Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.purchasesTotal),
                  ),
                  stat2Icon: Icons.percent_rounded,
                  stat2Label: 'Tax',
                  stat2Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.taxTotal),
                  ),
                );
              }
              return _PeriodRow(
                summary: summaries[index - 1],
                periodType: periodType,
              );
            },
          );
        },
      ),
    );
  }
}

class _BySupplierView extends ConsumerWidget {
  const _BySupplierView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(supplierSummariesProvider);
    final query = ref.watch(reportsSearchQueryProvider).trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(supplierSummariesProvider),
      child: AsyncValueView<List<SupplierSummary>>(
        value: summariesAsync,
        onRetry: () => ref.invalidate(supplierSummariesProvider),
        loading: (_) => const ListSkeleton(),
        data: (allSummaries) {
          final summaries = query.isEmpty
              ? allSummaries
              : allSummaries
                    .where((s) => s.supplierName.toLowerCase().contains(query))
                    .toList();

          if (allSummaries.isEmpty) {
            return const _ReportsEmptyState(
              message:
                  'Once you have invoices in your vault, tax reports will appear here.',
            );
          }
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryTiles(
                  countIcon: Icons.storefront_rounded,
                  countLabel: '${summaries.length}',
                  countSuffix: 'suppliers',
                  stat1Icon: Icons.shopping_bag_outlined,
                  stat1Label: 'Purchases',
                  stat1Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.purchasesTotal),
                  ),
                  stat2Icon: Icons.percent_rounded,
                  stat2Label: 'Tax',
                  stat2Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.taxTotal),
                  ),
                );
              }
              return _SupplierRow(summary: summaries[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _TransactionsByPeriodView extends ConsumerWidget {
  const _TransactionsByPeriodView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodType = ref.watch(selectedPeriodTypeProvider);
    final summariesAsync = ref.watch(transactionPeriodSummariesProvider);
    final query = ref.watch(reportsSearchQueryProvider).trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(transactionPeriodSummariesProvider),
      child: AsyncValueView<List<TransactionPeriodSummary>>(
        value: summariesAsync,
        onRetry: () => ref.invalidate(transactionPeriodSummariesProvider),
        loading: (_) => const ListSkeleton(),
        data: (allSummaries) {
          final summaries = query.isEmpty
              ? allSummaries
              : allSummaries
                    .where(
                      (s) => _periodLabel(
                        periodType,
                        s.periodStart,
                      ).toLowerCase().contains(query),
                    )
                    .toList();

          if (allSummaries.isEmpty) {
            return const _ReportsEmptyState(
              message:
                  'Once you have bank transactions in your vault, reports will appear here.',
            );
          }
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryTiles(
                  countIcon: Icons.account_balance_wallet_rounded,
                  countLabel:
                      '${summaries.fold<int>(0, (a, s) => a + s.transactionCount)}',
                  countSuffix: 'transactions',
                  stat1Icon: Icons.arrow_downward_rounded,
                  stat1Label: 'Received',
                  stat1Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.creditTotal),
                  ),
                  stat2Icon: Icons.arrow_upward_rounded,
                  stat2Label: 'Sent',
                  stat2Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.debitTotal),
                  ),
                );
              }
              return _TransactionPeriodRow(
                summary: summaries[index - 1],
                periodType: periodType,
              );
            },
          );
        },
      ),
    );
  }
}

class _ByCounterpartyView extends ConsumerWidget {
  const _ByCounterpartyView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(counterpartySummariesProvider);
    final query = ref.watch(reportsSearchQueryProvider).trim().toLowerCase();

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(counterpartySummariesProvider),
      child: AsyncValueView<List<CounterpartySummary>>(
        value: summariesAsync,
        onRetry: () => ref.invalidate(counterpartySummariesProvider),
        loading: (_) => const ListSkeleton(),
        data: (allSummaries) {
          final summaries = query.isEmpty
              ? allSummaries
              : allSummaries
                    .where(
                      (s) => s.counterpartyName.toLowerCase().contains(query),
                    )
                    .toList();

          if (allSummaries.isEmpty) {
            return const _ReportsEmptyState(
              message:
                  'Once you have bank transactions in your vault, reports will appear here.',
            );
          }
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryTiles(
                  countIcon: Icons.people_alt_rounded,
                  countLabel: '${summaries.length}',
                  countSuffix: 'counterparties',
                  stat1Icon: Icons.arrow_downward_rounded,
                  stat1Label: 'Received',
                  stat1Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.creditTotal),
                  ),
                  stat2Icon: Icons.arrow_upward_rounded,
                  stat2Label: 'Sent',
                  stat2Value: _currencyFormat.format(
                    summaries.fold<double>(0, (a, s) => a + s.debitTotal),
                  ),
                );
              }
              return _CounterpartyRow(summary: summaries[index - 1]);
            },
          );
        },
      ),
    );
  }
}

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSpacing.giant),
        EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'No reports yet',
          message: message,
        ),
      ],
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: AppSpacing.giant),
        EmptyState(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: 'Nothing matches "$query".',
        ),
      ],
    );
  }
}

/// Three colorful gradient tiles instead of one plain white card — the same
/// visual language as the Dashboard's insight tiles, so Reports reads as
/// part of the same considered product instead of a bare data table.
/// Generic over its icons/labels so both invoice totals (purchases/tax) and
/// transaction totals (received/sent) reuse the same tiles.
class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({
    required this.countIcon,
    required this.countLabel,
    required this.countSuffix,
    required this.stat1Icon,
    required this.stat1Label,
    required this.stat1Value,
    required this.stat2Icon,
    required this.stat2Label,
    required this.stat2Value,
  });

  final IconData countIcon;
  final String countLabel;
  final String countSuffix;
  final IconData stat1Icon;
  final String stat1Label;
  final String stat1Value;
  final IconData stat2Icon;
  final String stat2Label;
  final String stat2Value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: countIcon,
              value: countLabel,
              label: countSuffix,
              gradient: AppGradients.blue,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: stat1Icon,
              value: stat1Value,
              label: stat1Label,
              gradient: AppGradients.green,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _StatTile(
              icon: stat2Icon,
              value: stat2Value,
              label: stat2Label,
              gradient: AppGradients.coral,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String value;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A single clean row — icon, title/subtitle, trailing amount — matching
/// Vault's list style instead of a divider-heavy mini-card. Tapping drills
/// into Vault filtered to this period's date range.
class _PeriodRow extends ConsumerWidget {
  const _PeriodRow({required this.summary, required this.periodType});

  final PeriodSummary summary;
  final PeriodType periodType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final label = _periodLabel(periodType, summary.periodStart);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        ref
            .read(vaultControllerProvider.notifier)
            .setPeriodFilter(
              start: summary.periodStart,
              end: periodType.endOf(summary.periodStart),
              label: label,
            );
        context.go(AppRoutes.vault);
      },
      child: Row(
        children: [
          IconChip(
            icon: Icons.calendar_month_rounded,
            colorKey: label,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${summary.invoiceCount} invoice${summary.invoiceCount == 1 ? '' : 's'}'
                  ' · ${_currencyFormat.format(summary.taxTotal)} tax',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(summary.purchasesTotal),
                style: theme.textTheme.titleMedium,
              ),
              if (summary.needsReviewCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${summary.needsReviewCount} to review',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SupplierRow extends ConsumerWidget {
  const _SupplierRow({required this.summary});

  final SupplierSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        ref
            .read(vaultControllerProvider.notifier)
            .setSearchQuery(summary.supplierName);
        context.go(AppRoutes.vault);
      },
      child: Row(
        children: [
          IconChip(
            icon: Icons.storefront_outlined,
            colorKey: summary.supplierName,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.supplierName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.invoiceCount} invoice${summary.invoiceCount == 1 ? '' : 's'}'
                  '${summary.lastInvoiceDate != null ? ' · last ${_dateFormat.format(summary.lastInvoiceDate!)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _currencyFormat.format(summary.purchasesTotal),
                style: theme.textTheme.titleMedium,
              ),
              if (summary.needsReviewCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${summary.needsReviewCount} to review',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionPeriodRow extends ConsumerWidget {
  const _TransactionPeriodRow({required this.summary, required this.periodType});

  final TransactionPeriodSummary summary;
  final PeriodType periodType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final label = _periodLabel(periodType, summary.periodStart);
    final net = summary.creditTotal - summary.debitTotal;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        ref
            .read(bankTransactionsControllerProvider.notifier)
            .setPeriodFilter(
              start: summary.periodStart,
              end: periodType.endOf(summary.periodStart),
              label: label,
            );
        ref.read(selectedVaultViewProvider.notifier).state =
            VaultView.bankTransactions;
        context.go(AppRoutes.vault);
      },
      child: Row(
        children: [
          IconChip(
            icon: Icons.calendar_month_rounded,
            colorKey: label,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${net >= 0 ? '+' : '-'}${_currencyFormat.format(net.abs())}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: net >= 0 ? semantic.success : theme.colorScheme.error,
                ),
              ),
              if (summary.needsReviewCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${summary.needsReviewCount} to review',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CounterpartyRow extends ConsumerWidget {
  const _CounterpartyRow({required this.summary});

  final CounterpartySummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final net = summary.creditTotal - summary.debitTotal;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () {
        ref
            .read(bankTransactionsControllerProvider.notifier)
            .setSearchQuery(summary.counterpartyName);
        ref.read(selectedVaultViewProvider.notifier).state =
            VaultView.bankTransactions;
        context.go(AppRoutes.vault);
      },
      child: Row(
        children: [
          IconChip(
            icon: Icons.person_outline_rounded,
            colorKey: summary.counterpartyName,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.counterpartyName,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${summary.transactionCount} transaction${summary.transactionCount == 1 ? '' : 's'}'
                  '${summary.lastTransactionDate != null ? ' · last ${_dateFormat.format(summary.lastTransactionDate!)}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${net >= 0 ? '+' : '-'}${_currencyFormat.format(net.abs())}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: net >= 0 ? semantic.success : theme.colorScheme.error,
                ),
              ),
              if (summary.needsReviewCount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '${summary.needsReviewCount} to review',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: semantic.warning,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
