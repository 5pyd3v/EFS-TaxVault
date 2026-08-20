class InvoiceItemLine {
  const InvoiceItemLine({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.taxAmount,
    required this.totalAmount,
  });

  final String description;
  final double quantity;
  final double unitPrice;
  final double taxAmount;
  final double totalAmount;

  factory InvoiceItemLine.fromMap(Map<String, dynamic> map) {
    return InvoiceItemLine(
      description: map['description'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
      taxAmount: (map['tax_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AiWarning {
  const AiWarning({required this.severity, required this.message});

  final String severity;
  final String message;

  factory AiWarning.fromMap(Map<String, dynamic> map) {
    return AiWarning(
      severity: map['severity'] as String? ?? 'warning',
      message: map['message'] as String? ?? '',
    );
  }
}

/// The reviewable invoice: AI-extracted fields the user can correct, plus
/// the warnings and calculation-mismatch flag that justify review in the
/// first place. Editable fields mirror `invoices` columns 1:1 so a save is
/// a direct update, not a reinterpretation.
class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.supplierName,
    required this.supplierNtn,
    required this.subtotal,
    required this.discount,
    required this.salesTax,
    required this.otherTaxes,
    required this.totalAmount,
    required this.calculationMismatch,
    required this.verificationStatus,
    required this.aiConfidence,
    required this.items,
    required this.warnings,
    this.documentStoragePath,
    this.documentPageCount = 0,
    this.rejectionReason,
  });

  final String id;
  final String invoiceNumber;
  final String invoiceDate;
  final String supplierName;
  final String supplierNtn;
  final double subtotal;
  final double discount;
  final double salesTax;
  final double otherTaxes;
  final double totalAmount;
  final bool calculationMismatch;
  final String verificationStatus;
  final Map<String, dynamic> aiConfidence;
  final List<InvoiceItemLine> items;
  final List<AiWarning> warnings;

  /// Null when the source document was deleted independently of this
  /// invoice (`documents.id` on `invoices.document_id` is `on delete set
  /// null`) — in that case there's no original scan left to view.
  final String? documentStoragePath;
  final int documentPageCount;

  /// Set only when [verificationStatus] is `rejected` and the approver gave
  /// a reason.
  final String? rejectionReason;

  bool get hasScannedDocument =>
      documentStoragePath != null &&
      documentStoragePath!.isNotEmpty &&
      documentPageCount > 0;

  double confidenceFor(String field) =>
      (aiConfidence[field] as num?)?.toDouble() ?? 1.0;

  factory InvoiceDetail.fromMap(
    Map<String, dynamic> invoice, {
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> warnings,
    required String supplierName,
  }) {
    final document = invoice['documents'] as Map<String, dynamic>?;
    return InvoiceDetail(
      id: invoice['id'] as String,
      invoiceNumber: invoice['invoice_number'] as String? ?? '',
      invoiceDate: invoice['invoice_date'] as String? ?? '',
      supplierName: supplierName,
      supplierNtn: '',
      subtotal: (invoice['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (invoice['discount'] as num?)?.toDouble() ?? 0,
      salesTax: (invoice['sales_tax'] as num?)?.toDouble() ?? 0,
      otherTaxes: (invoice['other_taxes'] as num?)?.toDouble() ?? 0,
      totalAmount: (invoice['total_amount'] as num?)?.toDouble() ?? 0,
      calculationMismatch: invoice['calculation_mismatch'] as bool? ?? false,
      verificationStatus:
          invoice['verification_status'] as String? ?? 'needs_review',
      aiConfidence:
          (invoice['ai_confidence'] as Map?)?.cast<String, dynamic>() ??
          const {},
      items: items.map(InvoiceItemLine.fromMap).toList(),
      warnings: warnings.map(AiWarning.fromMap).toList(),
      documentStoragePath: document?['storage_path'] as String?,
      documentPageCount: (document?['page_count'] as num?)?.toInt() ?? 0,
      rejectionReason: invoice['rejection_reason'] as String?,
    );
  }
}
