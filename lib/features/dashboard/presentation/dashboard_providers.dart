import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_repository.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepositoryImpl(ref.watch(supabaseClientProvider));
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return DashboardSummary.empty();

  final result = await ref
      .watch(dashboardRepositoryProvider)
      .getSummary(org.id);
  return result.fold((summary) => summary, (failure) => throw failure);
});

/// Last 6 months of tax totals, oldest first — powers the hero card's
/// sparkline and month-over-month trend badge. Reuses the same
/// `get_period_summaries` RPC Reports already calls, just scoped monthly.
final monthlyTaxTrendProvider = FutureProvider<List<PeriodSummary>>((
  ref,
) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return const [];

  final result = await ref
      .watch(reportsRepositoryProvider)
      .getPeriodSummaries(
        organizationId: org.id,
        periodType: PeriodType.monthly,
      );
  return result.fold((summaries) {
    final sorted = [...summaries]
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return sorted.length > 6 ? sorted.sublist(sorted.length - 6) : sorted;
  }, (failure) => throw failure);
});

final recentInvoicesProvider = FutureProvider<List<InvoiceSummary>>((
  ref,
) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return const [];

  final result = await ref
      .watch(vaultRepositoryProvider)
      .listInvoices(
        organizationId: org.id,
        filter: VaultFilter.all,
        sort: VaultSort.newest,
        offset: 0,
        limit: 5,
      );
  return result.fold((items) => items, (failure) => throw failure);
});
