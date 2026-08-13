import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai/domain/ai_processing_repository.dart';
import 'package:fbr_taxvault/features/ai/domain/extraction_outcome.dart';

class AiProcessingRepositoryImpl implements AiProcessingRepository {
  AiProcessingRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<ExtractionOutcome>> extractInvoice(
    String documentId, {
    bool force = false,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'extract-invoice',
        body: {'document_id': documentId, 'force': force},
      );
      final data = response.data;
      if (data is Map && data['duplicate'] == true) {
        return Result.ok(
          ExtractionDuplicate(
            existingInvoiceId: data['existing_invoice_id'] as String,
            existingInvoiceNumber: data['existing_invoice_number'] as String?,
            existingTotalAmount: (data['existing_total_amount'] as num?)
                ?.toDouble(),
          ),
        );
      }
      if (data is Map && data['invoice_id'] is String) {
        return Result.ok(ExtractionSuccess(data['invoice_id'] as String));
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
