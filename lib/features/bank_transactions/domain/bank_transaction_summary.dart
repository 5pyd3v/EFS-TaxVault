/// A lightweight row for the Bank Transactions list — full field detail
/// lives in [BankTransactionDetail], fetched only when the user opens one.
class BankTransactionSummary {
  const BankTransactionSummary({
    required this.id,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    required this.counterpartyName,
    required this.bankName,
    required this.verificationStatus,
    this.createdBy,
  });

  final String id;

  /// `'debit'` or `'credit'`.
  final String direction;
  final double amount;
  final String currency;
  final DateTime? transactionDate;
  final String counterpartyName;
  final String bankName;
  final String verificationStatus;

  /// Who scanned this transaction — used by the approval queue to show
  /// "You" vs. a team member's name. Null unless explicitly selected.
  final String? createdBy;

  factory BankTransactionSummary.fromMap(Map<String, dynamic> map) {
    final dateString = map['transaction_date'] as String?;
    return BankTransactionSummary(
      id: map['id'] as String,
      direction: map['direction'] as String? ?? 'debit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'PKR',
      transactionDate: dateString != null
          ? DateTime.tryParse(dateString)
          : null,
      counterpartyName: map['counterparty_name'] as String? ?? 'Unknown',
      bankName: map['bank_name'] as String? ?? '',
      verificationStatus:
          map['verification_status'] as String? ?? 'needs_review',
      createdBy: map['created_by'] as String?,
    );
  }
}
