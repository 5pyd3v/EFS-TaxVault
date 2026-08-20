import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/team/data/team_repository_impl.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';
import 'package:fbr_taxvault/features/team/domain/team_repository.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// Staff belonging to the current organization (owner/admin excluded — see
/// TeamScreen). Empty for an individual org or before one is known.
final teamMembersProvider = FutureProvider<List<TeamMember>>((ref) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return const [];
  final result = await ref.watch(teamRepositoryProvider).listMembers(org.id);
  return result.fold((members) => members, (failure) => throw failure);
});
