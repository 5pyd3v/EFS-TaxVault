enum DocumentType {
  invoice('invoice'),
  bankTransaction('bank_transaction');

  const DocumentType(this.value);

  /// Matches the `documents.document_type` check constraint
  /// (supabase/migrations/0003, 0020, 0022).
  final String value;

  static DocumentType fromValue(String value) {
    return DocumentType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DocumentType.invoice,
    );
  }
}
