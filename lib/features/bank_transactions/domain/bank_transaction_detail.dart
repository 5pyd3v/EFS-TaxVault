/// The reviewable transaction: AI-extracted fields the user can correct.
/// Editable fields mirror `bank_transactions` columns 1:1 so a save is a
/// direct update, matching the pattern in `InvoiceDetail`.
class BankTransactionDetail {
  const BankTransactionDetail({
    required this.id,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.transactionDate,
    required this.counterpartyName,
    required this.counterpartyAccount,
    required this.bankName,
    required this.referenceNumber,
    required this.status,
    required this.verificationStatus,
    required this.aiConfidence,
    this.documentStoragePath,
    this.documentPageCount = 0,
    this.rejectionReason,
  });

  final String id;
  final String direction;
  final double amount;
  final String currency;
  final String transactionDate;
  final String counterpartyName;
  final String counterpartyAccount;
  final String bankName;
  final String referenceNumber;
  final String status;
  final String verificationStatus;
  final Map<String, dynamic> aiConfidence;

  /// Null when the source document was deleted independently of this
  /// transaction (`documents.id` on `bank_transactions.document_id` is `on
  /// delete set null`) — in that case there's no original scan left to view.
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

  factory BankTransactionDetail.fromMap(Map<String, dynamic> map) {
    final document = map['documents'] as Map<String, dynamic>?;
    return BankTransactionDetail(
      id: map['id'] as String,
      direction: map['direction'] as String? ?? 'debit',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'PKR',
      transactionDate: map['transaction_date'] as String? ?? '',
      counterpartyName: map['counterparty_name'] as String? ?? '',
      counterpartyAccount: map['counterparty_account'] as String? ?? '',
      bankName: map['bank_name'] as String? ?? '',
      referenceNumber: map['reference_number'] as String? ?? '',
      status: map['status'] as String? ?? '',
      verificationStatus:
          map['verification_status'] as String? ?? 'needs_review',
      aiConfidence:
          (map['ai_confidence'] as Map?)?.cast<String, dynamic>() ?? const {},
      documentStoragePath: document?['storage_path'] as String?,
      documentPageCount: (document?['page_count'] as num?)?.toInt() ?? 0,
      rejectionReason: map['rejection_reason'] as String?,
    );
  }
}
