import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';

/// Every invoice in the org an admin has disputed, newest first — approver
/// only (gated at the UI level by [isApproverProvider]; RLS/RPCs enforce
/// it server-side regardless). Every scan is auto-accepted on submission —
/// `rejected` only happens when an admin actively disputes it, so this is
/// the exception queue, not a review backlog.
final disputedInvoicesProvider = FutureProvider<List<InvoiceSummary>>((
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
        limit: 100,
        verificationStatus: 'rejected',
      );
  return result.fold((items) => items, (failure) => throw failure);
});

final disputedBankTransactionsProvider =
    FutureProvider<List<BankTransactionSummary>>((ref) async {
      final org = ref.watch(currentOrganizationProvider);
      if (org == null) return const [];
      final result = await ref
          .watch(bankTransactionRepositoryProvider)
          .listTransactions(
            organizationId: org.id,
            offset: 0,
            limit: 100,
            verificationStatus: 'rejected',
          );
      return result.fold((items) => items, (failure) => throw failure);
    });

/// Exact org-wide disputed count (independent of the 100-row list caps
/// above) — used for the Profile "Disputes" tile subtitle.
final disputedCountProvider = FutureProvider<int>((ref) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return 0;

  final invoiceResult = await ref
      .watch(vaultRepositoryProvider)
      .countDisputed(org.id);
  final transactionResult = await ref
      .watch(bankTransactionRepositoryProvider)
      .countDisputed(org.id);

  final invoiceCount = invoiceResult.fold((count) => count, (_) => 0);
  final transactionCount = transactionResult.fold((count) => count, (_) => 0);
  return invoiceCount + transactionCount;
});
