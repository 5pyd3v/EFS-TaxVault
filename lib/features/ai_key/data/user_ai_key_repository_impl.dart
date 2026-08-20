import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai_key/domain/gemini_key_status.dart';
import 'package:fbr_taxvault/features/ai_key/domain/user_ai_key_repository.dart';

class UserAiKeyRepositoryImpl implements UserAiKeyRepository {
  UserAiKeyRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<GeminiKeyStatus>> getStatus(String organizationId) async {
    try {
      final row = await _client
          .rpc(
            'get_my_gemini_key_status',
            params: {'p_organization_id': organizationId},
          )
          .single();
      return Result.ok(GeminiKeyStatus.fromMap(row));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> setApiKey(String organizationId, String apiKey) async {
    try {
      await _client.rpc(
        'set_my_gemini_api_key',
        params: {'p_organization_id': organizationId, 'p_api_key': apiKey},
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
}
