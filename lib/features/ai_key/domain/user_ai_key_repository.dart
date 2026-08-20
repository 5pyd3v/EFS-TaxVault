import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai_key/domain/gemini_key_status.dart';

/// Per-user Gemini key override, additive on top of the org-level key
/// ([AiKeyRepository]) — any org member may set their own key; when they
/// haven't, extraction falls back to the organization's key
/// (see supabase/functions/_shared/gemini_key.ts).
abstract interface class UserAiKeyRepository {
  Future<Result<GeminiKeyStatus>> getStatus(String organizationId);

  Future<Result<void>> setApiKey(String organizationId, String apiKey);
}
