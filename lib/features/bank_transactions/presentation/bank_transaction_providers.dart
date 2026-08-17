import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/data/bank_transaction_ai_repository_impl.dart';
import 'package:fbr_taxvault/features/bank_transactions/data/bank_transaction_export_service.dart';
import 'package:fbr_taxvault/features/bank_transactions/data/bank_transaction_repository_impl.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_ai_repository.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_detail.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_repository.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';

final bankTransactionRepositoryProvider = Provider<BankTransactionRepository>((
  ref,
) {
  return BankTransactionRepositoryImpl(ref.watch(supabaseClientProvider));
});

final bankTransactionAiRepositoryProvider =
    Provider<BankTransactionAiRepository>((ref) {
      return BankTransactionAiRepositoryImpl(ref.watch(supabaseClientProvider));
    });

final bankTransactionExportServiceProvider =
    Provider<BankTransactionExportService>((ref) {
      return BankTransactionExportService(ref.watch(supabaseClientProvider));
    });

final bankTransactionDetailProvider =
    FutureProvider.family<BankTransactionDetail, String>((
      ref,
      transactionId,
    ) async {
      final result = await ref
          .watch(bankTransactionRepositoryProvider)
          .getDetail(transactionId);
      return result.fold((detail) => detail, (failure) => throw failure);
    });

class BankTransactionsState {
  const BankTransactionsState({
    this.searchQuery = '',
    this.periodStart,
    this.periodEnd,
    this.periodLabel,
    this.items = const [],
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final String searchQuery;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? periodLabel;
  final List<BankTransactionSummary> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  BankTransactionsState copyWith({
    List<BankTransactionSummary>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return BankTransactionsState(
      searchQuery: searchQuery,
      periodStart: periodStart,
      periodEnd: periodEnd,
      periodLabel: periodLabel,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }
}

/// Pagination + search controller for the Bank Transactions list — same
/// shape as `VaultController`, trimmed down (no document-type filter/sort,
/// since transactions don't have those).
class BankTransactionsController extends Notifier<BankTransactionsState> {
  static const pageSize = 25;
  static const _searchDebounce = Duration(milliseconds: 350);

  Timer? _debounce;

  @override
  BankTransactionsState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const BankTransactionsState();
  }

  Future<void> refresh() async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    state = BankTransactionsState(
      searchQuery: state.searchQuery,
      periodStart: state.periodStart,
      periodEnd: state.periodEnd,
      periodLabel: state.periodLabel,
      isLoading: true,
    );
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .listTransactions(
          organizationId: organization.id,
          searchQuery: state.searchQuery,
          periodStart: state.periodStart,
          periodEnd: state.periodEnd,
          offset: 0,
          limit: pageSize,
        );

    state = result.fold(
      (items) => BankTransactionsState(
        searchQuery: state.searchQuery,
        periodStart: state.periodStart,
        periodEnd: state.periodEnd,
        periodLabel: state.periodLabel,
        items: items,
        isLoading: false,
        hasMore: items.length == pageSize,
      ),
      (failure) => BankTransactionsState(
        searchQuery: state.searchQuery,
        periodStart: state.periodStart,
        periodEnd: state.periodEnd,
        periodLabel: state.periodLabel,
        isLoading: false,
        errorMessage: failure.message,
      ),
    );
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    state = state.copyWith(isLoadingMore: true);
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .listTransactions(
          organizationId: organization.id,
          searchQuery: state.searchQuery,
          periodStart: state.periodStart,
          periodEnd: state.periodEnd,
          offset: state.items.length,
          limit: pageSize,
        );

    state = result.fold(
      (items) => state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: items.length == pageSize,
      ),
      (failure) =>
          state.copyWith(isLoadingMore: false, errorMessage: failure.message),
    );
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = BankTransactionsState(
      searchQuery: query,
      periodStart: state.periodStart,
      periodEnd: state.periodEnd,
      periodLabel: state.periodLabel,
    );
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, refresh);
  }

  /// Drill into a Reports period row — scopes the list to transactions
  /// dated within `[start, end)` for that period.
  void setPeriodFilter({
    required DateTime start,
    required DateTime end,
    required String label,
  }) {
    state = BankTransactionsState(
      searchQuery: '',
      periodStart: start,
      periodEnd: end,
      periodLabel: label,
    );
    refresh();
  }

  void clearPeriodFilter() {
    if (state.periodStart == null) return;
    state = BankTransactionsState(searchQuery: state.searchQuery);
    refresh();
  }
}

final bankTransactionsControllerProvider =
    NotifierProvider<BankTransactionsController, BankTransactionsState>(
      BankTransactionsController.new,
    );
