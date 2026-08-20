import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';

abstract interface class TeamRepository {
  Future<Result<List<TeamMember>>> listMembers(String organizationId);

  Future<Result<NewTeamMemberCredentials>> createMember({
    required String organizationId,
    required String fullName,
    required String phone,
    required OrganizationRole role,
  });

  /// Returns the fresh plaintext PIN, shown once to the admin.
  Future<Result<String>> regeneratePin({
    required String userId,
    required String organizationId,
  });

  Future<Result<void>> removeMember({
    required String userId,
    required String organizationId,
  });

  Future<Result<void>> setMemberGeminiKey({
    required String userId,
    required String organizationId,
    required String apiKey,
  });
}
