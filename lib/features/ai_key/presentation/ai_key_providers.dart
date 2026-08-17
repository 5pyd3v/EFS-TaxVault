import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/ai_key/data/ai_key_repository_impl.dart';
import 'package:fbr_taxvault/features/ai_key/domain/ai_key_repository.dart';
import 'package:fbr_taxvault/features/ai_key/domain/gemini_key_status.dart';

final aiKeyRepositoryProvider = Provider<AiKeyRepository>((ref) {
  return AiKeyRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// Cached per organization — invalidate after a successful `setApiKey` call
/// so Profile, the Scan-tab gate, and this settings screen all pick up the
/// change immediately (same stale-cache discipline as `invoiceDetailProvider`).
final geminiKeyStatusProvider = FutureProvider.family<GeminiKeyStatus, String>(
  (ref, organizationId) async {
    final result = await ref
        .watch(aiKeyRepositoryProvider)
        .getStatus(organizationId);
    return result.fold((status) => status, (failure) => throw failure);
  },
);
