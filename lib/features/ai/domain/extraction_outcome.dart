/// Result of one `extract-invoice` call. A duplicate is not a failure —
/// extraction succeeded, but the Edge Function stopped short of creating a
/// second invoice for a receipt that already exists and is handing the
/// decision back to the user (spec §16: "View Existing" or "Save Anyway").
sealed class ExtractionOutcome {
  const ExtractionOutcome();
}

class ExtractionSuccess extends ExtractionOutcome {
  const ExtractionSuccess(this.invoiceId);
  final String invoiceId;
}

class ExtractionDuplicate extends ExtractionOutcome {
  const ExtractionDuplicate({
    required this.existingInvoiceId,
    this.existingInvoiceNumber,
    this.existingTotalAmount,
  });

  final String existingInvoiceId;
  final String? existingInvoiceNumber;
  final double? existingTotalAmount;
}

/// The org's Gemini API key is missing, exhausted, or rejected —
/// `code` is one of `no_api_key` / `quota_exceeded` / `invalid_key`, set by
/// the Edge Function. Not a generic failure: the fix is always "go update
/// the key in Profile", so the UI shows a dedicated prompt with that action
/// rather than a plain error message.
class ExtractionKeyError extends ExtractionOutcome {
  const ExtractionKeyError(this.code, this.message);

  final String code;
  final String message;
}
