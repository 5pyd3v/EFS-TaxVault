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
