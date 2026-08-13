import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/ai/data/ai_processing_repository_impl.dart';
import 'package:fbr_taxvault/features/ai/domain/ai_processing_repository.dart';
import 'package:fbr_taxvault/features/ai/domain/extraction_outcome.dart';

final aiProcessingRepositoryProvider = Provider<AiProcessingRepository>((ref) {
  return AiProcessingRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// One-shot extraction per document id (force=false). `family` keys the
/// cache by documentId so re-entering the processing screen for the same
/// document doesn't re-trigger Gemini; `ref.invalidate` (the Retry action)
/// is the only way to run it again. A "Save anyway" after a duplicate
/// prompt calls the repository directly instead of going through this
/// cached provider — see ProcessingScreen.
final aiExtractionProvider = FutureProvider.family<ExtractionOutcome, String>((
  ref,
  documentId,
) async {
  final result = await ref
      .watch(aiProcessingRepositoryProvider)
      .extractInvoice(documentId);
  return result.fold((outcome) => outcome, (failure) => throw failure);
});
