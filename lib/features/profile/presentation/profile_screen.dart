import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_controller.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final organization = ref.watch(currentOrganizationProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(
                    _initial(user?.displayName),
                    style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.displayName ?? '', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? '',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          if (organization != null)
            _ProfileTile(
              icon: Icons.apartment_rounded,
              title: organization.name,
              subtitle: 'Your role: ${organization.role.name}',
            ),
          const SizedBox(height: AppSpacing.xxxl),
          OutlinedButton.icon(
            onPressed: authState.isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

String _initial(String? name) {
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
    );
  }
}
