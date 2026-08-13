import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/data/auth_repository_impl.dart';
import 'package:fbr_taxvault/features/auth/data/organization_repository_impl.dart';
import 'package:fbr_taxvault/features/auth/domain/app_user.dart';
import 'package:fbr_taxvault/features/auth/domain/auth_repository.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/domain/organization_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(supabaseClientProvider));
});

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// The signed-in user, or null. Rebuilds whenever Supabase's auth state
/// changes (sign in, sign out, token refresh) — this is what the router's
/// redirect logic watches.
final currentUserProvider = Provider<AppUser?>((ref) {
  ref.watch(authStateChangesProvider);
  return ref.watch(authRepositoryProvider).currentUser;
});

/// Organizations the current user belongs to. Empty once signed in but
/// before onboarding creates the first organization.
final myOrganizationsProvider = FutureProvider<List<Organization>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final result = await ref
      .watch(organizationRepositoryProvider)
      .getMyOrganizations();
  return result.fold((orgs) => orgs, (failure) => throw failure);
});

/// The active organization. Assumes a single organization per user for now
/// (first one returned) — an organization switcher is future work once
/// multi-org membership is exposed in the UI.
final currentOrganizationProvider = Provider<Organization?>((ref) {
  return ref
      .watch(myOrganizationsProvider)
      .maybeWhen(
        data: (orgs) => orgs.isEmpty ? null : orgs.first,
        orElse: () => null,
      );
});
