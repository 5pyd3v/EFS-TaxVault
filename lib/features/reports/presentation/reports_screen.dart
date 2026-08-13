import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_providers.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_controller.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
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

    setState(() => _isExporting = true);
    final result = await ref
        .read(reportExportServiceProvider)
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
    final view = ref.watch(selectedReportViewProvider);
    final query = ref.watch(reportsSearchQueryProvider);

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
            child: SegmentedButton<ReportView>(
              segments: const [
                ButtonSegment(
                  value: ReportView.byPeriod,
                  label: Text('By period'),
                ),
                ButtonSegment(
                  value: ReportView.bySupplier,
                  label: Text('By supplier'),
                ),
              ],
              selected: {view},
              onSelectionChanged: (selection) =>
                  ref.read(selectedReportViewProvider.notifier).state =
                      selection.first,
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
                    : 'Search suppliers',
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
          Expanded(
            child: view == ReportView.byPeriod
                ? const _ByPeriodView()
                : const _BySupplierView(),
          ),
        ],
      ),
    );
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

          if (allSummaries.isEmpty) return const _ReportsEmptyState();
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryCard(
                  countLabel:
                      '${summaries.fold<int>(0, (a, s) => a + s.invoiceCount)}',
                  purchasesTotal: summaries.fold<double>(
                    0,
                    (a, s) => a + s.purchasesTotal,
                  ),
                  taxTotal: summaries.fold<double>(0, (a, s) => a + s.taxTotal),
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

          if (allSummaries.isEmpty) return const _ReportsEmptyState();
          if (summaries.isEmpty) return _NoSearchResults(query: query);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: summaries.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SummaryCard(
                  countLabel: '${summaries.length}',
                  countSuffix: 'suppliers',
                  purchasesTotal: summaries.fold<double>(
                    0,
                    (a, s) => a + s.purchasesTotal,
                  ),
                  taxTotal: summaries.fold<double>(0, (a, s) => a + s.taxTotal),
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

class _ReportsEmptyState extends StatelessWidget {
  const _ReportsEmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: AppSpacing.giant),
        EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'No reports yet',
          message:
              'Once you have invoices in your vault, tax reports will appear here.',
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

/// One neutral card holding the whole view's totals — three columns, not
/// three separate colored tiles. A single quiet summary, not a wall of
/// color competing with the list below it.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.countLabel,
    required this.purchasesTotal,
    required this.taxTotal,
    this.countSuffix = 'invoices',
  });

  final String countLabel;
  final String countSuffix;
  final double purchasesTotal;
  final double taxTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: _SummaryStat(label: countSuffix, value: countLabel),
            ),
            _VerticalDivider(theme: theme),
            Expanded(
              child: _SummaryStat(
                label: 'Purchases',
                value: _currencyFormat.format(purchasesTotal),
              ),
            ),
            _VerticalDivider(theme: theme),
            Expanded(
              child: _SummaryStat(
                label: 'Tax',
                value: _currencyFormat.format(taxTotal),
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: theme.colorScheme.outline);
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
