enum DocumentType {
  invoice('invoice'),
  receipt('receipt'),
  taxDocument('tax_document'),
  other('other');

  const DocumentType(this.value);

  /// Matches the `documents.document_type` / `invoices.document_type`
  /// check constraints (supabase/migrations/0003, 0004).
  final String value;

  static DocumentType fromValue(String value) {
    return DocumentType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DocumentType.other,
    );
  }
}
