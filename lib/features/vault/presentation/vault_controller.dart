import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';

class VaultState {
  const VaultState({
    this.sort = VaultSort.newest,
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

  final VaultSort sort;
  final String searchQuery;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String? periodLabel;
  final List<InvoiceSummary> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;

  VaultState copyWith({
    List<InvoiceSummary>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return VaultState(
      sort: sort,
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

class VaultController extends Notifier<VaultState> {
  static const pageSize = 25;
  static const _searchDebounce = Duration(milliseconds: 350);

  Timer? _debounce;

  @override
  VaultState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const VaultState();
  }

  Future<void> refresh() async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    state = VaultState(
      sort: state.sort,
      searchQuery: state.searchQuery,
      periodStart: state.periodStart,
      periodEnd: state.periodEnd,
      periodLabel: state.periodLabel,
      isLoading: true,
    );
    final result = await ref
        .read(vaultRepositoryProvider)
        .listInvoices(
          organizationId: organization.id,
          sort: state.sort,
          searchQuery: state.searchQuery,
          periodStart: state.periodStart,
          periodEnd: state.periodEnd,
          offset: 0,
          limit: pageSize,
        );

    state = result.fold(
      (items) => VaultState(
        sort: state.sort,
        searchQuery: state.searchQuery,
        periodStart: state.periodStart,
        periodEnd: state.periodEnd,
        periodLabel: state.periodLabel,
        items: items,
        isLoading: false,
        hasMore: items.length == pageSize,
      ),
      (failure) => VaultState(
        sort: state.sort,
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
        .read(vaultRepositoryProvider)
        .listInvoices(
          organizationId: organization.id,
          sort: state.sort,
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

  void setSort(VaultSort sort) {
    if (sort == state.sort) return;
    state = VaultState(
      sort: sort,
      searchQuery: state.searchQuery,
      periodStart: state.periodStart,
      periodEnd: state.periodEnd,
      periodLabel: state.periodLabel,
    );
    refresh();
  }

  void setSearchQuery(String query) {
    if (query == state.searchQuery) return;
    state = VaultState(
      sort: state.sort,
      searchQuery: query,
      periodStart: state.periodStart,
      periodEnd: state.periodEnd,
      periodLabel: state.periodLabel,
    );
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, refresh);
  }

  /// Drill into a Reports period row — scopes the vault list to invoices
  /// dated within `[start, end)` for that period.
  void setPeriodFilter({
    required DateTime start,
    required DateTime end,
    required String label,
  }) {
    state = VaultState(
      sort: state.sort,
      searchQuery: '',
      periodStart: start,
      periodEnd: end,
      periodLabel: label,
    );
    refresh();
  }

  void clearPeriodFilter() {
    if (state.periodStart == null) return;
    state = VaultState(sort: state.sort, searchQuery: state.searchQuery);
    refresh();
  }
}

final vaultControllerProvider = NotifierProvider<VaultController, VaultState>(
  VaultController.new,
);
