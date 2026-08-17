import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_ai_repository.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_extraction_outcome.dart';

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
      final message = (details is Map && details['error'] is String)
          ? details['error'] as String
          : 'Could not analyze this document. Please try again.';
      return Result.err(ServerFailure(message));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
