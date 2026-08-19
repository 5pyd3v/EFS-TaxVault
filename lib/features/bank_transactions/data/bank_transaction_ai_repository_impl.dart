import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_ai_repository.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_extraction_outcome.dart';

/// See ai_processing_repository_impl.dart for the reasoning — this mirrors
/// its client-side timeout ceiling.
const _extractionTimeout = Duration(seconds: 200);

class BankTransactionAiRepositoryImpl implements BankTransactionAiRepository {
  BankTransactionAiRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<BankTransactionExtractionOutcome>> extractBankTransaction(
    String documentId, {
    bool force = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'extract-bank-transaction',
        body: {'document_id': documentId, 'force': force},
        abortSignal: Future.delayed(_extractionTimeout),
      );
      final data = response.data;
      if (data is Map && data['duplicate'] == true) {
        return Result.ok(
          BankTransactionExtractionDuplicate(
            existingTransactionId: data['existing_transaction_id'] as String,
            existingReferenceNumber:
                data['existing_reference_number'] as String?,
            existingAmount: (data['existing_amount'] as num?)?.toDouble(),
          ),
        );
      }
      if (data is Map && data['transaction_id'] is String) {
        return Result.ok(
          BankTransactionExtractionSuccess(data['transaction_id'] as String),
        );
      }
      return const Result.err(
        ServerFailure(
          'The document was saved, but analysis did not return a result.',
        ),
      );
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error'] as String? : null;
      if (code == 'no_api_key' || code == 'quota_exceeded' || code == 'invalid_key') {
        final message = (details is Map && details['message'] is String)
            ? details['message'] as String
            : 'Please update your Gemini API key in Profile.';
        return Result.ok(BankTransactionExtractionKeyError(code!, message));
      }
      final message = code ?? 'Could not analyze this document. Please try again.';
      return Result.err(ServerFailure(message));
    } on RequestAbortedException {
      return const Result.err(
        ServerFailure(
          'Analysis is taking longer than expected. Please try again.',
        ),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
