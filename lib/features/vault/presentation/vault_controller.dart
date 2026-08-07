import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_providers.dart';

class VaultState {
  const VaultState({
    this.filter = VaultFilter.all,
    this.sort = VaultSort.newest,
    this.items = const [],
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final VaultFilter filter;
  final VaultSort sort;
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
      filter: filter,
      sort: sort,
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

  @override
  VaultState build() => const VaultState();

  Future<void> refresh() async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    state = VaultState(filter: state.filter, sort: state.sort, isLoading: true);
    final result = await ref.read(vaultRepositoryProvider).listInvoices(
          organizationId: organization.id,
          filter: state.filter,
          sort: state.sort,
          offset: 0,
          limit: pageSize,
        );

    state = result.fold(
      (items) => VaultState(
        filter: state.filter,
        sort: state.sort,
        items: items,
        isLoading: false,
        hasMore: items.length == pageSize,
      ),
      (failure) => VaultState(
        filter: state.filter,
        sort: state.sort,
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
    final result = await ref.read(vaultRepositoryProvider).listInvoices(
          organizationId: organization.id,
          filter: state.filter,
          sort: state.sort,
          offset: state.items.length,
          limit: pageSize,
        );

    state = result.fold(
      (items) => state.copyWith(
        items: [...state.items, ...items],
        isLoadingMore: false,
        hasMore: items.length == pageSize,
      ),
      (failure) => state.copyWith(isLoadingMore: false, errorMessage: failure.message),
    );
  }

  void setFilter(VaultFilter filter) {
    if (filter == state.filter) return;
    state = VaultState(filter: filter, sort: state.sort);
    refresh();
  }

  void setSort(VaultSort sort) {
    if (sort == state.sort) return;
    state = VaultState(filter: state.filter, sort: sort);
    refresh();
  }
}

final vaultControllerProvider = NotifierProvider<VaultController, VaultState>(
  VaultController.new,
);
