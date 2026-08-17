import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';
import 'package:fbr_taxvault/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_repository.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/dashboard/domain/recent_activity_item.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart' show VaultSort;
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

final recentInvoicesProvider = FutureProvider<List<InvoiceSummary>>((
  ref,
) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return const [];

  final result = await ref
      .watch(vaultRepositoryProvider)
      .listInvoices(
        organizationId: org.id,
        sort: VaultSort.newest,
        offset: 0,
        limit: 5,
      );
  return result.fold((items) => items, (failure) => throw failure);
});

final recentBankTransactionsProvider =
    FutureProvider<List<BankTransactionSummary>>((ref) async {
      final org = ref.watch(currentOrganizationProvider);
      if (org == null) return const [];

      final result = await ref
          .watch(bankTransactionRepositoryProvider)
          .listTransactions(organizationId: org.id, offset: 0, limit: 5);
      return result.fold((items) => items, (failure) => throw failure);
    });

/// Merges the two most-recent lists above into one date-ordered feed —
/// depends on both via `.future`, so invalidating either source
/// (`refreshInvoiceDependentState` / `refreshBankTransactionDependentState`)
/// automatically recomputes this too.
final recentActivityProvider = FutureProvider<List<RecentActivityItem>>((
  ref,
) async {
  final invoices = await ref.watch(recentInvoicesProvider.future);
  final transactions = await ref.watch(recentBankTransactionsProvider.future);

  final combined = <RecentActivityItem>[
    ...invoices.map(RecentInvoiceActivity.new),
    ...transactions.map(RecentBankTransactionActivity.new),
  ]..sort((a, b) {
    final aDate = a.date;
    final bDate = b.date;
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return bDate.compareTo(aDate);
  });

  return combined.take(5).toList();
});
