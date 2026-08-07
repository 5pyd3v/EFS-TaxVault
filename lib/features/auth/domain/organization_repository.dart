import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';

abstract interface class OrganizationRepository {
  Future<Result<List<Organization>>> getMyOrganizations();

  Future<Result<Organization>> createOrganization({
    required String name,
    required OrganizationType type,
  });
}
