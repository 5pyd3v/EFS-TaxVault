import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/ai/data/ai_processing_repository_impl.dart';
import 'package:fbr_taxvault/features/ai/domain/ai_processing_repository.dart';

final aiProcessingRepositoryProvider = Provider<AiProcessingRepository>((ref) {
  return AiProcessingRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// One-shot extraction per document id. `family` keys the cache by
/// documentId so re-entering the processing screen for the same document
/// doesn't re-trigger Gemini; `ref.invalidate` (the Retry action) is the
/// only way to run it again.
final aiExtractionProvider = FutureProvider.family<String, String>((ref, documentId) async {
  final result = await ref.watch(aiProcessingRepositoryProvider).extractInvoice(documentId);
  return result.fold((invoiceId) => invoiceId, (failure) => throw failure);
});
