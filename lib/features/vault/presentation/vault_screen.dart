import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_controller.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';

final _currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'PKR ', decimalDigits: 0);
final _dateFormat = DateFormat('d MMM yyyy');

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(vaultControllerProvider);
    final controller = ref.read(vaultControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault'),
        actions: [
          PopupMenuButton<VaultSort>(
            initialValue: state.sort,
            onSelected: controller.setSort,
            icon: const Icon(Icons.sort_rounded),
            itemBuilder: (context) => VaultSort.values
                .map((sort) => PopupMenuItem(value: sort, child: Text(sort.label)))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
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
      return const Center(child: CircularProgressIndicator());
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
            onAction: () => ref.read(vaultControllerProvider.notifier).refresh(),
          ),
        ],
      );
    }
    if (state.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: AppSpacing.giant),
          EmptyState(
            icon: Icons.folder_open_outlined,
            title: 'No documents here yet',
            message: 'Scan your first invoice and TaxVault will organize the rest.',
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

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice});

  final InvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final (statusColor, statusLabel) = switch (invoice.verificationStatus) {
      'verified' => (semantic.success, 'Verified'),
      'rejected' => (theme.colorScheme.error, 'Rejected'),
      _ => (semantic.warning, 'Needs review'),
    };

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
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
                      if (invoice.invoiceNumber.isNotEmpty) '#${invoice.invoiceNumber}',
                      if (invoice.invoiceDate != null) _dateFormat.format(invoice.invoiceDate!),
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
                Text(_currencyFormat.format(invoice.totalAmount), style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
