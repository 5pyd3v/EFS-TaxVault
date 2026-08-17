import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_extraction_outcome.dart';

abstract interface class BankTransactionAiRepository {
  /// Invokes the `extract-bank-transaction` Edge Function — the only place
  /// Gemini is called from for this document type. Pass [force] true only
  /// after the user has explicitly chosen "Save anyway" on a duplicate
  /// prompt.
  Future<Result<BankTransactionExtractionOutcome>> extractBankTransaction(
    String documentId, {
    bool force = false,
  });
}
