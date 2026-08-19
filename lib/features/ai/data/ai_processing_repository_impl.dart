import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai/domain/ai_processing_repository.dart';
import 'package:fbr_taxvault/features/ai/domain/extraction_outcome.dart';

/// Server-side (see gemini_fetch.ts) bounds worst-case Gemini call time to
/// roughly 3 minutes (primary: 2 attempts x 60s + backoff, fallback: 1 x
/// 60s). This client-side ceiling is the safety net on top of that — if
/// the Edge Function invocation itself never returns for any reason (a
/// platform-level hang, not just a slow Gemini response), the app gives up
/// with a clear error instead of leaving the "Analyzing" screen stuck
/// forever with no way out but to force-quit. Must stay comfortably above
/// the server-side bound above it.
const _extractionTimeout = Duration(seconds: 200);

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
        abortSignal: Future.delayed(_extractionTimeout),
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
      final code = details is Map ? details['error'] as String? : null;
      if (code == 'no_api_key' || code == 'quota_exceeded' || code == 'invalid_key') {
        final message = (details is Map && details['message'] is String)
            ? details['message'] as String
            : 'Please update your Gemini API key in Profile.';
        return Result.ok(ExtractionKeyError(code!, message));
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
