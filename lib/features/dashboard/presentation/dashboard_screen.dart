import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_semantic_colors.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/ai_key/presentation/ai_key_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';
import 'package:fbr_taxvault/features/dashboard/domain/recent_activity_item.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fbr_taxvault/features/notifications/presentation/notifications_providers.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';
import 'package:fbr_taxvault/shared/widgets/section_header.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'en_US',
  symbol: 'Rs ',
  decimalDigits: 0,
);
final _dateFormat = DateFormat('d MMM');

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xxl,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      _Avatar(name: user?.displayName),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greeting,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.displayName ?? '',
                              style: theme.textTheme.headlineSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const _NotificationBell(),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: AsyncValueView<DashboardSummary>(
                    value: summaryAsync,
                    onRetry: () => ref.invalidate(dashboardSummaryProvider),
                    loading: (_) => const _DashboardSkeleton(),
                    data: (summary) => _DashboardContent(summary: summary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trimmed = name?.trim() ?? '';
    final initial = trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppGradients.blue,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7CF6).withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasActivity =
        summary.totalInvoices > 0 || summary.totalBankTransactions > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _CurvedHeroCard(summary: summary),
            Positioned(
              left: AppSpacing.xxl,
              right: AppSpacing.xxl,
              bottom: -32,
              child: const _QuickActionsBar(),
            ),
          ],
        ),
        const SizedBox(height: 48),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ApiKeyNudgeBanner(),
              _InsightsCard(summary: summary),
              const SizedBox(height: AppSpacing.xxxl),
              SectionHeader(
                title: 'Recent activity',
                actionLabel: hasActivity ? 'See all' : null,
                onAction: hasActivity
                    ? () => context.go(AppRoutes.vault)
                    : null,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!hasActivity)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
                  child: EmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'Nothing here yet',
                    message:
                        'Scan your first invoice or bank receipt and TaxVault will organize the rest.',
                  ),
                )
              else
                const _RecentActivityList(),
              const SizedBox(height: AppSpacing.giant),
            ],
          ),
        ),
      ],
    );
  }
}

/// The dashboard's headline — an organic wave-bottom silhouette instead of a
/// plain rounded rectangle. Deliberately shows document *activity*, not a
/// money figure: TaxVault organizes documents, it doesn't total up a bank
/// balance, so leading with a currency amount (often just "Rs 0" for a
/// quiet month) sent the wrong signal about what this screen is for.
class _CurvedHeroCard extends StatelessWidget {
  const _CurvedHeroCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final documents = summary.currentMonthDocuments;

    return RepaintBoundary(
      child: ClipPath(
        clipper: const _WaveBottomClipper(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxl,
            AppSpacing.xl,
            AppSpacing.xxl,
            // Deliberately generous: the floating _QuickActionsBar overlaps
            // up into this card by its own height minus its -32 bottom
            // offset (~50px) — this padding has to clear that zone or the
            // card's own text ends up hidden underneath the floating bar.
            AppSpacing.giant + AppSpacing.xxxl,
          ),
          decoration: const BoxDecoration(gradient: AppGradients.blue),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documents scanned this month',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$documents',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 40,
                  height: 1,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Icon(
                    summary.pendingVerification > 0
                        ? Icons.fact_check_outlined
                        : Icons.check_circle_outline_rounded,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary.pendingVerification > 0
                          ? '${summary.pendingVerification} document${summary.pendingVerification == 1 ? '' : 's'} waiting for review'
                          : 'Everything is organized and up to date',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaveBottomClipper extends CustomClipper<Path> {
  const _WaveBottomClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 36)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height + 14,
        size.width,
        size.height - 36,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Floats over the hero's bottom edge — a considered layering trick (Cash
/// App/Revolut do this with their primary shortcuts) rather than a single
/// full-width CTA button.
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 24,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: _QuickAction(
              icon: Icons.document_scanner_rounded,
              label: 'Scan',
              emphasized: true,
              onTap: () => context.go(AppRoutes.scan),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.folder_rounded,
              label: 'Vault',
              onTap: () => context.go(AppRoutes.vault),
            ),
          ),
          Expanded(
            child: _QuickAction(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              onTap: () => context.go(AppRoutes.reports),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: emphasized ? AppGradients.blue : null,
                color: emphasized
                    ? null
                    : theme.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                boxShadow: emphasized
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFF2E7CF6,
                          ).withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: emphasized ? Colors.white : theme.colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A one-time nudge shown until the org configures a Gemini API key —
/// adding a key is optional/skippable at onboarding, so this is the
/// surface that eventually points people to it. Renders nothing once a key
/// is configured, and nothing while the status is still loading (avoids a
/// flash on every dashboard load).
class _ApiKeyNudgeBanner extends ConsumerWidget {
  const _ApiKeyNudgeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organization = ref.watch(currentOrganizationProvider);
    if (organization == null) return const SizedBox.shrink();

    final status = ref
        .watch(geminiKeyStatusProvider(organization.id))
        .valueOrNull;
    if (status == null || status.hasKey) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      child: AppCard(
        onTap: () => context.push(AppRoutes.aiKeySettings),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            IconChip(
              icon: Icons.vpn_key_outlined,
              color: theme.colorScheme.primary,
              size: 40,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add your Gemini API key',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Required to enable document scanning',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Replaces the old two-square-tile layout with one card, two tappable
/// Two colorful tiles instead of a plain list — a bold gradient when there's
/// something to act on, a soft tint when there isn't, so color itself
/// carries the "does this need me" signal rather than just a number.
class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;

    // IntrinsicHeight gives the Row a real height to stretch its children
    // against — without it, `stretch` inside this unbounded-height Column
    // (a scrollable sliver, not a fixed-size parent) fails to lay out at
    // all, silently collapsing this widget and everything after it in the
    // same Column to zero height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _InsightTile(
              icon: Icons.fact_check_rounded,
              label: 'Pending verification',
              count: summary.pendingVerification,
              gradient: AppGradients.amber,
              tintColor: semantic.warning,
              tintContainer: semantic.warningContainer,
              onTap: () => context.go(AppRoutes.vault),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _InsightTile(
              icon: Icons.error_rounded,
              label: 'Potential issues',
              count: summary.potentialIssues,
              gradient: AppGradients.coral,
              tintColor: theme.colorScheme.error,
              tintContainer: theme.colorScheme.errorContainer,
              onTap: () => context.go(AppRoutes.vault),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.label,
    required this.count,
    required this.gradient,
    required this.tintColor,
    required this.tintContainer,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final Gradient gradient;
  final Color tintColor;
  final Color tintContainer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = count > 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            gradient: active ? gradient : null,
            color: active ? null : tintContainer,
            borderRadius: BorderRadius.circular(20),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: tintColor.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    icon,
                    color: active ? Colors.white : tintColor,
                    size: 22,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: active
                        ? Colors.white.withValues(alpha: 0.8)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '$count',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: active ? Colors.white : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: active
                      ? Colors.white.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends ConsumerWidget {
  const _RecentActivityList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentActivityProvider);

    return AsyncValueView<List<RecentActivityItem>>(
      value: recentAsync,
      loading: (_) => const SizedBox.shrink(),
      data: (items) => Column(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: switch (item) {
                RecentInvoiceActivity() => _InvoiceActivityTile(
                  invoice: item.invoice,
                ),
                RecentBankTransactionActivity() => _TransactionActivityTile(
                  transaction: item.transaction,
                ),
              },
            ),
        ],
      ),
    );
  }
}

class _InvoiceActivityTile extends StatelessWidget {
  const _InvoiceActivityTile({required this.invoice});

  final InvoiceSummary invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: () => context.push(AppRoutes.invoiceReview(invoice.id)),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          IconChip(
            icon: Icons.storefront_outlined,
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
                  _relativeLabel(invoice.invoiceDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _currencyFormat.format(invoice.totalAmount),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _TransactionActivityTile extends StatelessWidget {
  const _TransactionActivityTile({required this.transaction});

  final BankTransactionSummary transaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<AppSemanticColors>()!;
    final isCredit = transaction.direction == 'credit';
    final amountColor = isCredit
        ? semantic.success
        : theme.colorScheme.onSurface;

    return AppCard(
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
                  _relativeLabel(transaction.transactionDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isCredit ? '+' : '-'}${_currencyFormat.format(transaction.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(color: amountColor),
          ),
        ],
      ),
    );
  }
}

String _relativeLabel(DateTime? date) {
  if (date == null) return 'Undated';
  final today = DateTime.now();
  final diff = DateTime(
    today.year,
    today.month,
    today.day,
  ).difference(DateTime(date.year, date.month, date.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
  return _dateFormat.format(date);
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.4,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: AppSpacing.giant),
          Container(
            height: 108,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadAsync = ref.watch(unreadNotificationsCountProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => context.push(AppRoutes.notifications),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16213E).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              Icons.notifications_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (unreadCount > 0)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  unreadCount > 9 ? '9+' : '$unreadCount',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onError,
                    fontSize: 9,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
