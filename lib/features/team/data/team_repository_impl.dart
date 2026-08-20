import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';
import 'package:fbr_taxvault/features/team/domain/team_repository.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<TeamMember>>> listMembers(String organizationId) async {
    try {
      final rows = await _client.rpc(
        'list_team_members',
        params: {'p_organization_id': organizationId},
      );
      final members = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(TeamMember.fromMap)
          .toList();
      return Result.ok(members);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<NewTeamMemberCredentials>> createMember({
    required String organizationId,
    required String fullName,
    required String phone,
    required OrganizationRole role,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-team-member',
        body: {
          'organization_id': organizationId,
          'full_name': fullName,
          'phone': phone,
          'role': role.name,
        },
      );
      final data = response.data as Map<String, dynamic>;
      return Result.ok(NewTeamMemberCredentials.fromMap(data));
    } on FunctionException catch (e) {
      return Result.err(ServerFailure(_functionErrorMessage(e)));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<String>> regeneratePin({
    required String userId,
    required String organizationId,
  }) async {
    try {
      final pin =
          await _client.rpc(
                'regenerate_member_pin',
                params: {
                  'p_user_id': userId,
                  'p_organization_id': organizationId,
                },
              )
              as String;
      return Result.ok(pin);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> removeMember({
    required String userId,
    required String organizationId,
  }) async {
    try {
      await _client.rpc(
        'remove_team_member',
        params: {'p_user_id': userId, 'p_organization_id': organizationId},
      );
      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> setMemberGeminiKey({
    required String userId,
    required String organizationId,
    required String apiKey,
  }) async {
    try {
      await _client.rpc(
        'admin_set_member_gemini_key',
        params: {
          'p_user_id': userId,
          'p_organization_id': organizationId,
          'p_api_key': apiKey,
        },
      );
      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  // create-team-member always responds with a single `{ error: '<readable
  // text>' }` field on failure (confirmed by reading its source directly —
  // it has no separate `message` field), unlike login-with-pin's two-field
  // `{ error: code, message: text }` shape. Reading `message` here — as an
  // earlier version of this did — silently discarded every specific
  // reason (duplicate phone, wrong org type, not authorized...) in favor
  // of the generic fallback below, on every single failure.
  String _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Could not complete that action. Please try again.';
  }
}
