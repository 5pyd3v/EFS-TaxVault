import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_repository.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submission.dart';
import 'package:fbr_taxvault/features/fbr/domain/fbr_submit_outcome.dart';

class FbrRepositoryImpl implements FbrRepository {
  FbrRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<FbrSubmission?>> getSubmission(String invoiceId) async {
    try {
      final row = await _client
          .from('fbr_submissions')
          .select('status, external_reference, submitted_at, adapter_version')
          .eq('invoice_id', invoiceId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return Result.ok(row == null ? null : FbrSubmission.fromMap(row));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<FbrSubmitOutcome>> submit(
    String invoiceId, {
    bool force = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'submit-to-fbr',
        body: {'invoice_id': invoiceId, 'force': force},
      );
      final data = response.data;
      if (data is Map && data['already_submitted'] == true) {
        return Result.ok(
          FbrSubmitAlreadySubmitted(data['external_reference'] as String?),
        );
      }
      if (data is Map && data['status'] == 'accepted') {
        return Result.ok(
          FbrSubmitAccepted(data['external_reference'] as String),
        );
      }
      return const Result.err(
        ServerFailure('FBR submission did not return a result.'),
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['errors'] is List) {
        return Result.ok(
          FbrSubmitValidationFailed((details['errors'] as List).cast<String>()),
        );
      }
      final message = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Could not submit to FBR. Please try again.';
      return Result.err(ServerFailure(message));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
