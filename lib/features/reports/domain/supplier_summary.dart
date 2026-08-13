/// Invoices grouped by supplier — "how many invoices from this vendor,
/// and how much" — computed by `get_supplier_summaries` in Postgres.
class SupplierSummary {
  const SupplierSummary({
    required this.supplierId,
    required this.supplierName,
    required this.invoiceCount,
    required this.purchasesTotal,
    required this.taxTotal,
    required this.needsReviewCount,
    required this.lastInvoiceDate,
  });

  final String supplierId;
  final String supplierName;
  final int invoiceCount;
  final double purchasesTotal;
  final double taxTotal;
  final int needsReviewCount;
  final DateTime? lastInvoiceDate;

  factory SupplierSummary.fromMap(Map<String, dynamic> map) {
    final lastDate = map['last_invoice_date'] as String?;
    return SupplierSummary(
      supplierId: map['supplier_id'] as String,
      supplierName: map['supplier_name'] as String? ?? 'Unknown supplier',
      invoiceCount: (map['invoice_count'] as num?)?.toInt() ?? 0,
      purchasesTotal: (map['purchases_total'] as num?)?.toDouble() ?? 0,
      taxTotal: (map['tax_total'] as num?)?.toDouble() ?? 0,
      needsReviewCount: (map['needs_review_count'] as num?)?.toInt() ?? 0,
      lastInvoiceDate: lastDate != null ? DateTime.tryParse(lastDate) : null,
    );
  }
}
