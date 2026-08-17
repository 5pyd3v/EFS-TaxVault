/// One row of the bank-transaction period report — mirrors `PeriodSummary`
/// (invoices), computed by `get_bank_transaction_period_summaries` in
/// Postgres. Split into credit/debit rather than a single purchases/tax
/// total, since a transaction receipt has neither of those concepts.
class TransactionPeriodSummary {
  const TransactionPeriodSummary({
    required this.periodStart,
    required this.transactionCount,
    required this.creditTotal,
    required this.debitTotal,
    required this.needsReviewCount,
  });

  final DateTime periodStart;
  final int transactionCount;
  final double creditTotal;
  final double debitTotal;
  final int needsReviewCount;

  factory TransactionPeriodSummary.fromMap(Map<String, dynamic> map) {
    return TransactionPeriodSummary(
      periodStart: DateTime.parse(map['period_start'] as String),
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      creditTotal: (map['credit_total'] as num?)?.toDouble() ?? 0,
      debitTotal: (map['debit_total'] as num?)?.toDouble() ?? 0,
      needsReviewCount: (map['needs_review_count'] as num?)?.toInt() ?? 0,
    );
  }
}
