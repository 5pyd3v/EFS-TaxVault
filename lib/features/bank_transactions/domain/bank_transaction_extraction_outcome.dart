/// Result of one `extract-bank-transaction` call — mirrors
/// `ExtractionOutcome` (invoices). A duplicate is not a failure: extraction
/// succeeded, but the Edge Function stopped short of creating a second
/// transaction for a receipt that already exists.
sealed class BankTransactionExtractionOutcome {
  const BankTransactionExtractionOutcome();
}

class BankTransactionExtractionSuccess
    extends BankTransactionExtractionOutcome {
  const BankTransactionExtractionSuccess(this.transactionId);
  final String transactionId;
}

class BankTransactionExtractionDuplicate
    extends BankTransactionExtractionOutcome {
  const BankTransactionExtractionDuplicate({
    required this.existingTransactionId,
    this.existingReferenceNumber,
    this.existingAmount,
  });

  final String existingTransactionId;
  final String? existingReferenceNumber;
  final double? existingAmount;
}

/// The org's Gemini API key is missing, exhausted, or rejected — mirrors
/// `ExtractionKeyError` (invoices). `code` is one of `no_api_key` /
/// `quota_exceeded` / `invalid_key`, set by the Edge Function.
class BankTransactionExtractionKeyError
    extends BankTransactionExtractionOutcome {
  const BankTransactionExtractionKeyError(this.code, this.message);

  final String code;
  final String message;
}
