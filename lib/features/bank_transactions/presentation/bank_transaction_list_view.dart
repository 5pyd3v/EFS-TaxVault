import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/bank_transactions/presentation/bank_transaction_providers.dart';
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

/// The Bank Transactions segment of Vault — search field + list, with the
/// same swipe-to-delete `AppCard` rows as the Documents segment. Deliberately
/// has no `Scaffold`/`AppBar` of its own: it's embedded directly inside
/// `VaultScreen`, which owns the segmented toggle and AppBar actions.
class BankTransactionsListView extends ConsumerStatefulWidget {
  const BankTransactionsListView({super.key});

  @override
  ConsumerState<BankTransactionsListView> createState() =>
      _BankTransactionsListViewState();
}

class _BankTransactionsListViewState
    extends ConsumerState<BankTransactionsListView> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(bankTransactionsControllerProvider).searchQuery;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bankTransactionsControllerProvider.notifier).refresh();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(bankTransactionsControllerProvider.notifier).loadMore();
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
    final state = ref.watch(bankTransactionsControllerProvider);
    final controller = ref.read(bankTransactionsControllerProvider.notifier);

    if (_searchController.text != state.searchQuery) {
      _searchController.text = state.searchQuery;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: controller.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'Search counterparty, bank, or reference',
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
        Expanded(
          child: RefreshIndicator(
            onRefresh: controller.refresh,
            child: _buildBody(theme, state),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(ThemeData theme, BankTransactionsState state) {
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
            title: 'Could not load your transactions',
            message: state.errorMessage!,
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(bankTransactionsControllerProvider.notifier).refresh(),
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
                : Icons.account_balance_wallet_outlined,
            title: searching || filteringByPeriod
                ? 'No matches'
                : 'No transactions yet',
            message: searching
                ? 'No transactions match "${state.searchQuery}".'
                : filteringByPeriod
                ? 'No transactions found for ${state.periodLabel}.'
                : 'Scan a bank receipt from the Scan tab and TaxVault will keep track of it here.',
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
        return _TransactionTile(transaction: state.items[index]);
      },
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({required this.transaction});

  final BankTransactionSummary transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final isCredit = transaction.direction == 'credit';
    final amountColor = isCredit
        ? semantic.success
        : theme.colorScheme.onSurface;
    final (statusColor, statusLabel) = switch (transaction.verificationStatus) {
      'verified' => (semantic.success, 'Verified'),
      'rejected' => (theme.colorScheme.error, 'Rejected'),
      _ => (semantic.warning, 'Needs review'),
    };

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteTransaction(context, ref),
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
        onTap: () =>
            context.push(AppRoutes.bankTransactionReview(transaction.id)),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            IconChip(
              icon: isCredit
                  ? Icons.call_received_rounded
                  : Icons.call_made_rounded,
              colorKey: transaction.counterpartyName,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.counterpartyName,
                    style: theme.textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (transaction.bankName.isNotEmpty) transaction.bankName,
                      if (transaction.transactionDate != null)
                        _dateFormat.format(transaction.transactionDate!),
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
                  '${isCredit ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: amountColor,
                  ),
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
        title: const Text('Delete transaction?'),
        content: Text(
          'Remove "${transaction.counterpartyName}" and its scanned pages? This can\'t be undone.',
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

  Future<void> _deleteTransaction(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(bankTransactionRepositoryProvider)
        .deleteTransaction(transaction.id);
    ref.invalidate(bankTransactionDetailProvider(transaction.id));
    if (context.mounted) {
      result.fold(
        (_) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Transaction deleted.'))),
        (failure) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message))),
      );
    }
    refreshBankTransactionDependentState(ref);
  }
}
