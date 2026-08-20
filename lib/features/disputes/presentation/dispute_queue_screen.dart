import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/disputes/presentation/dispute_providers.dart';
import 'package:fbr_taxvault/features/team/presentation/team_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 2,
);

/// Owner/admin only — every invoice and transaction currently disputed
/// across the whole org, one flat entry list. Every scan is usable the
/// moment it's submitted; a dispute is the exception an admin raises, not
/// a review step everything waits in. Tapping a row reuses the existing
/// review screens (same route the submitter used), where the submitter or
/// admin can rescan it — this screen is purely the filtered queue, not a
/// second copy of the review UI.
class DisputeQueueScreen extends ConsumerWidget {
  const DisputeQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(disputedInvoicesProvider);
    final transactionsAsync = ref.watch(disputedBankTransactionsProvider);
    final currentUserId = ref.watch(currentUserProvider)?.id;
    final membersAsync = ref.watch(teamMembersProvider);
    final memberNames = {
      for (final m in membersAsync.valueOrNull ?? const [])
        m.userId: m.displayName,
    };

    String submitterName(String? createdBy) {
      if (createdBy == null) return 'Unknown';
      if (createdBy == currentUserId) return 'You';
      return memberNames[createdBy] ?? 'Team member';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Disputes')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(disputedInvoicesProvider);
          ref.invalidate(disputedBankTransactionsProvider);
        },
        child: AsyncValueView<List<InvoiceSummary>>(
          value: invoicesAsync,
          onRetry: () => ref.invalidate(disputedInvoicesProvider),
          data: (invoices) {
            return AsyncValueView<List<BankTransactionSummary>>(
              value: transactionsAsync,
              onRetry: () => ref.invalidate(disputedBankTransactionsProvider),
              data: (transactions) {
                if (invoices.isEmpty && transactions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No disputes',
                    message:
                        'Scans you dispute will show up here until the submitter rescans them.',
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  children: [
                    if (invoices.isNotEmpty) ...[
                      Text(
                        'Invoices',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final invoice in invoices) ...[
                        _InvoiceRow(
                          invoice: invoice,
                          submitterName: submitterName(invoice.createdBy),
                          onTap: () =>
                              context.push(AppRoutes.invoiceReview(invoice.id)),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (transactions.isNotEmpty) ...[
                      Text(
                        'Bank transactions',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final transaction in transactions) ...[
                        _TransactionRow(
                          transaction: transaction,
                          submitterName: submitterName(transaction.createdBy),
                          onTap: () => context.push(
                            AppRoutes.bankTransactionReview(transaction.id),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.submitterName,
    required this.onTap,
  });

  final InvoiceSummary invoice;
  final String submitterName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          IconChip(
            icon: Icons.receipt_long_rounded,
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
                  'Submitted by $submitterName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(invoice.totalAmount),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.submitterName,
    required this.onTap,
  });

  final BankTransactionSummary transaction;
  final String submitterName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.direction == 'credit';
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          IconChip(
            icon: isCredit
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded,
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
                  'Submitted by $submitterName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(transaction.amount),
            style: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
