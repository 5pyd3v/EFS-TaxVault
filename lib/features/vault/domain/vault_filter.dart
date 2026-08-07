import 'package:fbr_taxvault/shared/domain/document_type.dart';

enum VaultFilter {
  all(null, 'All Documents'),
  invoice(DocumentType.invoice, 'Invoices'),
  receipt(DocumentType.receipt, 'Receipts'),
  taxDocument(DocumentType.taxDocument, 'Tax Documents'),
  other(DocumentType.other, 'Other Documents');

  const VaultFilter(this.documentType, this.label);

  final DocumentType? documentType;
  final String label;
}

enum VaultSort {
  newest('Newest', 'invoice_date', ascending: false),
  oldest('Oldest', 'invoice_date', ascending: true),
  highestAmount('Highest amount', 'total_amount', ascending: false),
  lowestAmount('Lowest amount', 'total_amount', ascending: true);

  const VaultSort(this.label, this.column, {required this.ascending});

  final String label;
  final String column;
  final bool ascending;
}
