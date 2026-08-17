/// Bank transactions grouped by counterparty — mirrors `SupplierSummary`
/// (invoices), computed by `get_bank_transaction_counterparty_summaries`.
/// Counterparties aren't a stored entity (no id, just free text on the
/// transaction row), so the name doubles as the identifier here.
class CounterpartySummary {
  const CounterpartySummary({
    required this.counterpartyName,
    required this.transactionCount,
    required this.creditTotal,
    required this.debitTotal,
    required this.needsReviewCount,
    required this.lastTransactionDate,
  });

  final String counterpartyName;
  final int transactionCount;
  final double creditTotal;
  final double debitTotal;
  final int needsReviewCount;
  final DateTime? lastTransactionDate;

  factory CounterpartySummary.fromMap(Map<String, dynamic> map) {
    final lastDate = map['last_transaction_date'] as String?;
    return CounterpartySummary(
      counterpartyName:
          map['counterparty_name'] as String? ?? 'Unknown counterparty',
      transactionCount: (map['transaction_count'] as num?)?.toInt() ?? 0,
      creditTotal: (map['credit_total'] as num?)?.toDouble() ?? 0,
      debitTotal: (map['debit_total'] as num?)?.toDouble() ?? 0,
      needsReviewCount: (map['needs_review_count'] as num?)?.toInt() ?? 0,
      lastTransactionDate: lastDate != null
          ? DateTime.tryParse(lastDate)
          : null,
    );
  }
}
