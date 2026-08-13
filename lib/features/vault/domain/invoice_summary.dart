import 'package:fbr_taxvault/shared/domain/document_type.dart';

/// A lightweight row for the Vault list — full field-level detail (items,
/// warnings, confidence) lives in InvoiceDetail, fetched only when the user
/// opens one invoice.
class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.supplierName,
    required this.invoiceDate,
    required this.totalAmount,
    required this.currency,
    required this.documentType,
    required this.verificationStatus,
  });

  final String id;
  final String invoiceNumber;
  final String supplierName;
  final DateTime? invoiceDate;
  final double totalAmount;
  final String currency;
  final DocumentType documentType;
  final String verificationStatus;

  factory InvoiceSummary.fromMap(Map<String, dynamic> map) {
    final supplier = map['suppliers'] as Map<String, dynamic>?;
    final dateString = map['invoice_date'] as String?;
    return InvoiceSummary(
      id: map['id'] as String,
      invoiceNumber: map['invoice_number'] as String? ?? '',
      supplierName: supplier?['name'] as String? ?? 'Unknown supplier',
      invoiceDate: dateString != null ? DateTime.tryParse(dateString) : null,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'PKR',
      documentType: DocumentType.fromValue(
        map['document_type'] as String? ?? 'other',
      ),
      verificationStatus:
          map['verification_status'] as String? ?? 'needs_review',
    );
  }
}
