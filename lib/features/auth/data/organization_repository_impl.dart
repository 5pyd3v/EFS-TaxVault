import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/auth/domain/organization_repository.dart';

class OrganizationRepositoryImpl implements OrganizationRepository {
  OrganizationRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<Organization>>> getMyOrganizations() async {
    try {
      final rows = await _client
          .from('organization_members')
          .select('role, organizations(id, name, type)')
          .order('created_at');

      final organizations = rows.map((row) {
        final org = row['organizations'] as Map<String, dynamic>;
        return Organization.fromMap({
          'id': org['id'],
          'name': org['name'],
          'type': org['type'],
          'role': row['role'],
        });
      }).toList();

      return Result.ok(organizations);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<Organization>> createOrganization({
    required String name,
    required OrganizationType type,
  }) async {
    try {
      // `create_organization_with_owner` inserts the organization and the
      // caller's `owner` membership row in a single transaction, so an
      // organization is never left without a member (see
      // supabase/migrations/0009_triggers.sql).
      final orgId =
          await _client.rpc(
                'create_organization_with_owner',
                params: {'org_name': name, 'org_type': type.name},
              )
              as String;

      return Result.ok(
        Organization(
          id: orgId,
          name: name,
          type: type,
          role: OrganizationRole.owner,
        ),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
