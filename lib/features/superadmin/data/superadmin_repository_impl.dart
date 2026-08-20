import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';
import 'package:fbr_taxvault/features/superadmin/domain/superadmin_repository.dart';

class SuperadminRepositoryImpl implements SuperadminRepository {
  SuperadminRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<PlatformOrganization>>> listOrganizations() async {
    try {
      final rows = await _client.rpc('list_all_organizations');
      final organizations = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(PlatformOrganization.fromMap)
          .toList();
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
  Future<Result<List<IncompleteSignup>>> listIncompleteSignups() async {
    try {
      final rows = await _client.rpc('list_incomplete_signups');
      final signups = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(IncompleteSignup.fromMap)
          .toList();
      return Result.ok(signups);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> setBlocked({
    required String organizationId,
    required bool blocked,
    String? reason,
  }) async {
    try {
      await _client.rpc(
        'set_organization_blocked',
        params: {
          'p_organization_id': organizationId,
          'p_blocked': blocked,
          'p_reason': reason,
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

  @override
  Future<Result<NewSandboxCredentials>> createSandboxAccount({
    required String fullName,
    required String organizationName,
    String? email,
    String? geminiApiKey,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'create-sandbox-account',
        body: {
          'full_name': fullName,
          'organization_name': organizationName,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (geminiApiKey != null && geminiApiKey.trim().isNotEmpty)
            'gemini_api_key': geminiApiKey.trim(),
        },
      );
      final data = response.data as Map<String, dynamic>;
      return Result.ok(NewSandboxCredentials.fromMap(data));
    } on FunctionException catch (e) {
      return Result.err(ServerFailure(_functionErrorMessage(e)));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteIncompleteSignup(String userId) async {
    try {
      await _client.functions.invoke(
        'delete-platform-user',
        body: {'user_id': userId},
      );
      return const Result.ok(null);
    } on FunctionException catch (e) {
      return Result.err(ServerFailure(_functionErrorMessage(e)));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> deleteOrganization(String organizationId) async {
    try {
      await _client.functions.invoke(
        'delete-organization',
        body: {'organization_id': organizationId},
      );
      return const Result.ok(null);
    } on FunctionException catch (e) {
      return Result.err(ServerFailure(_functionErrorMessage(e)));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  // create-sandbox-account/delete-platform-user/delete-organization all
  // respond with a single `{ error: '<readable text>' }` field on failure,
  // not a separate `message` field — see TeamRepositoryImpl's identical
  // helper for the bug this convention fixes.
  String _functionErrorMessage(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return 'Could not complete that action. Please try again.';
  }
}
