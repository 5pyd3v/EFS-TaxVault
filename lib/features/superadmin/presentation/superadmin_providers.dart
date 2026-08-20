import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/superadmin/data/superadmin_repository_impl.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';
import 'package:fbr_taxvault/features/superadmin/domain/superadmin_repository.dart';

/// Whether the signed-in user has a `platform_admins` row. A plain
/// self-check query (RLS restricts it to the caller's own row — see
/// 0033_platform_admins.sql) rather than an RPC, since there's nothing to
/// gate: a user can always ask "is this me".
final platformAdminStatusProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserProvider)?.id;
  if (userId == null) return false;
  final row = await ref
      .watch(supabaseClientProvider)
      .from('platform_admins')
      .select('user_id')
      .eq('user_id', userId)
      .maybeSingle();
  return row != null;
});

/// Synchronous read for use in the router's `_redirect`, which can't await
/// a FutureProvider — same pattern as `currentOrganizationProvider` reading
/// `myOrganizationsProvider.valueOrNull`. Defaults to false while loading
/// or on error, so a redirect never treats an unresolved check as "yes".
final isPlatformAdminProvider = Provider<bool>((ref) {
  return ref.watch(platformAdminStatusProvider).valueOrNull ?? false;
});

final superadminRepositoryProvider = Provider<SuperadminRepository>((ref) {
  return SuperadminRepositoryImpl(ref.watch(supabaseClientProvider));
});

final allOrganizationsProvider = FutureProvider<List<PlatformOrganization>>((
  ref,
) async {
  final result = await ref
      .watch(superadminRepositoryProvider)
      .listOrganizations();
  return result.fold((orgs) => orgs, (failure) => throw failure);
});

final incompleteSignupsProvider = FutureProvider<List<IncompleteSignup>>((
  ref,
) async {
  final result = await ref
      .watch(superadminRepositoryProvider)
      .listIncompleteSignups();
  return result.fold((signups) => signups, (failure) => throw failure);
});
