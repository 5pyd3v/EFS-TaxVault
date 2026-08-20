import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';

abstract interface class SuperadminRepository {
  Future<Result<List<PlatformOrganization>>> listOrganizations();

  /// Real accounts that signed up but never finished onboarding — no
  /// organization, so invisible to [listOrganizations].
  Future<Result<List<IncompleteSignup>>> listIncompleteSignups();

  Future<Result<void>> setBlocked({
    required String organizationId,
    required bool blocked,
    String? reason,
  });

  Future<Result<NewSandboxCredentials>> createSandboxAccount({
    required String fullName,
    required String organizationName,
    String? email,
    String? geminiApiKey,
  });

  /// Deletes an org-less account entirely (safe — refuses server-side if
  /// the target has any organization membership).
  Future<Result<void>> deleteIncompleteSignup(String userId);

  /// Deletes an organization and everything scoped to it. Does NOT delete
  /// its members' accounts — they become org-less afterward.
  Future<Result<void>> deleteOrganization(String organizationId);
}
