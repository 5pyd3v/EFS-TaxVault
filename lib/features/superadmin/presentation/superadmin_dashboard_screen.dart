import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_gradients.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_controller.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_controller.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_providers.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

final _dateFormat = DateFormat('d MMM yyyy');

/// Platform-admin only — every organization on the platform (individual and
/// business), account metadata only. Never shows a customer's actual
/// scanned invoices/receipts/transactions — see 0034_organization_blocking_
/// and_sandbox.sql's list_all_organizations, which only ever selects from
/// organizations/organization_members/profiles.
class SuperadminDashboardScreen extends ConsumerWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationsAsync = ref.watch(allOrganizationsProvider);
    final signupsAsync = ref.watch(incompleteSignupsProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Admin'),
        actions: [
          IconButton(
            icon: authState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.createSandboxAccount),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Create sandbox'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(allOrganizationsProvider);
          ref.invalidate(incompleteSignupsProvider);
        },
        child: AsyncValueView<List<PlatformOrganization>>(
          value: organizationsAsync,
          onRetry: () => ref.invalidate(allOrganizationsProvider),
          data: (organizations) {
            return AsyncValueView<List<IncompleteSignup>>(
              value: signupsAsync,
              onRetry: () => ref.invalidate(incompleteSignupsProvider),
              data: (signups) {
                if (organizations.isEmpty && signups.isEmpty) {
                  return const EmptyState(
                    icon: Icons.apartment_outlined,
                    title: 'No organizations yet',
                    message:
                        'Every individual and business account will show up here.',
                  );
                }
                final businessCount = organizations
                    .where((o) => o.type == OrganizationType.business)
                    .length;
                final blockedCount = organizations
                    .where((o) => o.isBlocked)
                    .length;
                final sandboxCount = organizations
                    .where((o) => o.isSandbox)
                    .length;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  children: [
                    _StatsRow(
                      totalCount: organizations.length,
                      businessCount: businessCount,
                      blockedCount: blockedCount,
                      sandboxCount: sandboxCount,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    if (organizations.isNotEmpty) ...[
                      Text(
                        'Organizations',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final org in organizations) ...[
                        _OrganizationCard(organization: org),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                    if (signups.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Incomplete signups',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Signed up but never finished creating an account.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      for (final signup in signups) ...[
                        _IncompleteSignupCard(signup: signup),
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

/// Four gradient stat tiles giving the admin an at-a-glance read on the
/// whole platform before scrolling into individual accounts — same visual
/// language as Reports' `_SummaryTiles` (AppGradients, soft glow shadow),
/// so this screen reads as part of the same app rather than a bolted-on
/// admin panel.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.totalCount,
    required this.businessCount,
    required this.blockedCount,
    required this.sandboxCount,
  });

  final int totalCount;
  final int businessCount;
  final int blockedCount;
  final int sandboxCount;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.7,
      children: [
        _StatTile(
          icon: Icons.apartment_rounded,
          value: '$totalCount',
          label: 'Total accounts',
          gradient: AppGradients.blue,
        ),
        _StatTile(
          icon: Icons.business_center_rounded,
          value: '$businessCount',
          label: 'Business',
          gradient: AppGradients.violet,
        ),
        _StatTile(
          icon: Icons.block_rounded,
          value: '$blockedCount',
          label: 'Blocked',
          gradient: AppGradients.coral,
        ),
        _StatTile(
          icon: Icons.science_outlined,
          value: '$sandboxCount',
          label: 'Sandbox',
          gradient: AppGradients.amber,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String value;
  final String label;
  final LinearGradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrganizationCard extends ConsumerWidget {
  const _OrganizationCard({required this.organization});

  final PlatformOrganization organization;

  Future<void> _toggleBlocked(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final blocking = !organization.isBlocked;
    String? reason;

    if (blocking) {
      final reasonController = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Block ${organization.name}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Every member of this organization will be signed out and unable to sign in again until unblocked.',
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      reason = reasonController.text.trim();
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Unblock ${organization.name}?'),
          content: const Text(
            'Its members will be able to sign in again immediately.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Unblock'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final ok = await ref
        .read(superadminControllerProvider.notifier)
        .setBlocked(
          organizationId: organization.organizationId,
          blocked: blocking,
          reason: reason,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (blocking ? 'Blocked.' : 'Unblocked.')
                : 'Could not update this account. Please try again.',
          ),
        ),
      );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final matches = confirmController.text.trim() == organization.name;
          return AlertDialog(
            title: Text('Delete ${organization.name}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This permanently deletes the organization and every scan, invoice, and transaction in it — ${organization.memberCount} member${organization.memberCount == 1 ? '' : 's'} affected. This cannot be undone. Member accounts themselves are not deleted.',
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Type "${organization.name}" to confirm.',
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: confirmController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Organization name'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                onPressed: matches ? () => Navigator.of(context).pop(true) : null,
                child: const Text('Delete permanently'),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(superadminControllerProvider.notifier)
        .deleteOrganization(organization.organizationId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Deleted.' : 'Could not delete this organization. Please try again.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconChip(
            icon: organization.type == OrganizationType.business
                ? Icons.apartment_rounded
                : Icons.person_rounded,
            colorKey: organization.organizationId,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        organization.name,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (organization.isSandbox) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _Chip(label: 'Sandbox', color: theme.colorScheme.primary),
                    ],
                    if (organization.isBlocked) ...[
                      const SizedBox(width: AppSpacing.xs),
                      _Chip(label: 'Blocked', color: theme.colorScheme.error),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  organization.ownerName?.trim().isNotEmpty == true
                      ? '${organization.ownerName} · ${organization.ownerEmail}'
                      : organization.ownerEmail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${organization.type == OrganizationType.business ? 'Business' : 'Individual'} · '
                  '${organization.memberCount} member${organization.memberCount == 1 ? '' : 's'} · '
                  'since ${_dateFormat.format(organization.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) {
              if (action == 'toggle') {
                _toggleBlocked(context, ref);
              } else if (action == 'delete') {
                _delete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  organization.isBlocked ? 'Unblock' : 'Block',
                  style: organization.isBlocked
                      ? null
                      : TextStyle(color: theme.colorScheme.error),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncompleteSignupCard extends ConsumerWidget {
  const _IncompleteSignupCard({required this.signup});

  final IncompleteSignup signup;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final displayName = signup.fullName?.trim().isNotEmpty == true
        ? signup.fullName!
        : signup.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $displayName?'),
        content: const Text(
          'This permanently deletes the account. It has no organization or data attached, so nothing else is affected. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final ok = await ref
        .read(superadminControllerProvider.notifier)
        .deleteIncompleteSignup(signup.userId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? 'Deleted.' : 'Could not delete this account. Please try again.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          IconChip(icon: Icons.person_outline_rounded, colorKey: signup.userId),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signup.fullName?.trim().isNotEmpty == true
                      ? signup.fullName!
                      : signup.email,
                  style: theme.textTheme.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${signup.email} · signed up ${_dateFormat.format(signup.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
            tooltip: 'Delete account',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
