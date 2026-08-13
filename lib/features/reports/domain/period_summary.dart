/// One row of the tax-period report — everything computed by
/// `get_period_summaries` in Postgres, never client-side (spec §18).
class PeriodSummary {
  const PeriodSummary({
    required this.periodStart,
    required this.invoiceCount,
    required this.purchasesTotal,
    required this.taxTotal,
    required this.needsReviewCount,
  });

  final DateTime periodStart;
  final int invoiceCount;
  final double purchasesTotal;
  final double taxTotal;
  final int needsReviewCount;

  factory PeriodSummary.fromMap(Map<String, dynamic> map) {
    return PeriodSummary(
      periodStart: DateTime.parse(map['period_start'] as String),
      invoiceCount: (map['invoice_count'] as num?)?.toInt() ?? 0,
      purchasesTotal: (map['purchases_total'] as num?)?.toDouble() ?? 0,
      taxTotal: (map['tax_total'] as num?)?.toDouble() ?? 0,
      needsReviewCount: (map['needs_review_count'] as num?)?.toInt() ?? 0,
    );
  }
}
