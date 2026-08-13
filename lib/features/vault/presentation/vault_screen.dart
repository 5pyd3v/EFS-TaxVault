import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/invoices/presentation/invoice_review_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_controller.dart';
import 'package:fbr_taxvault/shared/domain/document_type.dart';
import 'package:fbr_taxvault/shared/providers/invoice_mutation_effects.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';
import 'package:fbr_taxvault/shared/widgets/list_skeleton.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);
final _dateFormat = DateFormat('d MMM yyyy');

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Reports' "By supplier" cards set the search query before navigating
    // here (see reports_screen.dart) — pick that up so the field shows
    // what's actually being searched instead of appearing empty.
    _searchController.text = ref.read(vaultControllerProvider).searchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(vaultControllerProvider.notifier).refresh();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(vaultControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(vaultControllerProvider);
    final controller = ref.read(vaultControllerProvider.notifier);

    // Reports' period/supplier cards set the search/period filter before
    // navigating here — this screen lives inside the bottom-nav shell's
    // IndexedStack so initState only runs once, meaning the visible field
    // won't otherwise pick up a query set on a later navigation.
    if (_searchController.text != state.searchQuery) {
      _searchController.text = state.searchQuery;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          PopupMenuButton<VaultSort>(
            initialValue: state.sort,
            onSelected: controller.setSort,
            icon: const Icon(Icons.sort_rounded),
            itemBuilder: (context) => VaultSort.values
                .map(
                  (sort) => PopupMenuItem(value: sort, child: Text(sort.label)),
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
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search invoice number or supplier',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: state.searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          controller.setSearchQuery('');
                        },
                      ),
              ),
            ),
          ),
          if (state.periodLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text('Period: ${state.periodLabel}'),
                  onDeleted: controller.clearPeriodFilter,
                ),
              ),
            ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: VaultFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final filter = VaultFilter.values[index];
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: state.filter == filter,
                  onSelected: (_) => controller.setFilter(filter),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: _buildBody(theme, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme, VaultState state) {
    if (state.isLoading) {
      return const ListSkeleton();
    }
    if (state.errorMessage != null && state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.giant),
          EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load your vault',
            message: state.errorMessage!,
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(vaultControllerProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      final searching = state.searchQuery.trim().isNotEmpty;
      final filteringByPeriod = state.periodLabel != null;
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: AppSpacing.giant),
          EmptyState(
            icon: searching || filteringByPeriod
                ? Icons.search_off_rounded
                : Icons.folder_open_outlined,
            title: searching || filteringByPeriod
                ? 'No matches'
                : 'No documents here yet',
            message: searching
                ? 'No invoices match "${state.searchQuery}".'
                : filteringByPeriod
                ? 'No invoices found for ${state.periodLabel}.'
                : 'Scan your first invoice and TaxVault will organize the rest.',
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _InvoiceTile(invoice: state.items[index]);
      },
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  const _InvoiceTile({required this.invoice});

  final InvoiceSummary invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (statusColor, statusLabel) = switch (invoice.verificationStatus) {
      'verified' => (semantic.success, 'Verified'),
      'rejected' => (theme.colorScheme.error, 'Rejected'),
      _ => (semantic.warning, 'Needs review'),
    };

    return Dismissible(
      key: ValueKey(invoice.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteInvoice(context, ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: AppCard(
        onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconChip(
              icon: _iconFor(invoice.documentType),
              colorKey: invoice.supplierName,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.supplierName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (invoice.invoiceNumber.isNotEmpty)
                        '#${invoice.invoiceNumber}',
                      if (invoice.invoiceDate != null)
                        _dateFormat.format(invoice.invoiceDate!),
                    ].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _currencyFormat.format(invoice.totalAmount),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete invoice?'),
        content: Text(
          'Remove "${invoice.supplierName}" and its scanned pages? This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteInvoice(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(invoiceRepositoryProvider)
        .deleteInvoice(invoice.id);
    if (context.mounted) {
      result.fold(
        (_) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Invoice deleted.'))),
        (failure) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message))),
      );
    }
    // Re-syncs with the server either way: fixes pagination offsets after a
    // real delete, and restores the row if the delete actually failed. Also
    // refreshes Dashboard/Reports so a deleted invoice doesn't linger there.
    refreshInvoiceDependentState(ref);
  }

  IconData _iconFor(DocumentType type) {
    return switch (type) {
      DocumentType.invoice => Icons.receipt_long_outlined,
      DocumentType.receipt => Icons.receipt_outlined,
      DocumentType.taxDocument => Icons.account_balance_outlined,
      DocumentType.other => Icons.description_outlined,
    };
  }
}
