import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/ai_key/domain/gemini_key_status.dart';

abstract interface class AiKeyRepository {
  Future<Result<GeminiKeyStatus>> getStatus(String organizationId);

  Future<Result<void>> setApiKey(String organizationId, String apiKey);
}
