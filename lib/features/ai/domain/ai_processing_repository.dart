import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai/domain/extraction_outcome.dart';

abstract interface class AiProcessingRepository {
  /// Invokes the `extract-invoice` Edge Function (the only place Gemini is
  /// called from) — extraction, deterministic validation, and duplicate
  /// detection all happen server-side before this returns. Pass
  /// [force] true only after the user has explicitly chosen "Save anyway"
  /// on a duplicate prompt.
  Future<Result<ExtractionOutcome>> extractInvoice(String documentId, {bool force = false});
}
