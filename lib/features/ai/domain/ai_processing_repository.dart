import 'package:fbr_taxvault/core/errors/result.dart';

abstract interface class AiProcessingRepository {
  /// Invokes the `extract-invoice` Edge Function (the only place Gemini is
  /// called from) and returns the id of the invoice it created. This is a
  /// single blocking call — the Edge Function does extraction, deterministic
  /// validation, duplicate detection, and invoice creation before
  /// responding, so there is no separate polling step.
  Future<Result<String>> extractInvoice(String documentId);
}
