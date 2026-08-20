import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';
import 'package:fbr_taxvault/features/team/presentation/team_controller.dart';
import 'package:fbr_taxvault/features/team/presentation/team_providers.dart';
import 'package:fbr_taxvault/shared/widgets/app_card.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

/// Admin-only staff list — regenerate a PIN, set a member's Gemini key on
/// their behalf, or remove them. The signed-in owner/admin's own row is
/// deliberately excluded: this screen manages the staff you're responsible
/// for, not your own account (that's Profile).
class TeamScreen extends ConsumerWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(teamMembersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.addTeamMember),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add member'),
      ),
      body: AsyncValueView<List<TeamMember>>(
        value: membersAsync,
        onRetry: () => ref.invalidate(teamMembersProvider),
        data: (members) {
          final staff = members
              .where(
                (m) =>
                    m.role != OrganizationRole.owner &&
                    m.role != OrganizationRole.admin,
              )
              .toList();
          if (staff.isEmpty) {
            return const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No team members yet',
              message:
                  'Add staff by name and phone — they sign in with a PIN you generate for them.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            itemCount: staff.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) =>
                _TeamMemberCard(member: staff[index]),
          );
        },
      ),
    );
  }
}

class _TeamMemberCard extends ConsumerWidget {
  const _TeamMemberCard({required this.member});

  final TeamMember member;

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final organization = ref.read(currentOrganizationProvider);
    if (organization == null) return;

    switch (action) {
      case 'regenerate_pin':
        await _regeneratePin(context, ref, organization.id);
      case 'set_key':
        await _setGeminiKey(context, ref, organization.id);
      case 'remove':
        await _removeMember(context, ref, organization.id);
    }
  }

  Future<void> _regeneratePin(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate a new PIN?'),
        content: Text(
          '${member.displayName}\'s current PIN will stop working immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pin = await ref
        .read(teamControllerProvider.notifier)
        .regeneratePin(userId: member.userId, organizationId: organizationId);
    if (pin == null || !context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share this with ${member.displayName} now — it won\'t be shown again.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              pin,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pin));
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _setGeminiKey(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
  ) async {
    final controller = TextEditingController();
    final apiKey = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set ${member.displayName}\'s Gemini key'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Gemini API key',
            hintText: 'AIza...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (apiKey == null || apiKey.length < 10 || !context.mounted) return;

    final ok = await ref
        .read(teamControllerProvider.notifier)
        .setMemberGeminiKey(
          userId: member.userId,
          organizationId: organizationId,
          apiKey: apiKey,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Key saved.' : 'Could not save the key. Please try again.',
          ),
        ),
      );
  }

  Future<void> _removeMember(
    BuildContext context,
    WidgetRef ref,
    String organizationId,
  ) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove team member?'),
        content: Text(
          '${member.displayName} will lose access immediately and won\'t be able to sign in again.',
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
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(teamControllerProvider.notifier)
        .removeMember(userId: member.userId, organizationId: organizationId);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          IconChip(icon: Icons.person_rounded, colorKey: member.userId),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  member.phone ?? 'No phone',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleAction(context, ref, action),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'regenerate_pin',
                child: Text('Regenerate PIN'),
              ),
              PopupMenuItem(value: 'set_key', child: Text('Set Gemini key')),
              PopupMenuItem(value: 'remove', child: Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}
