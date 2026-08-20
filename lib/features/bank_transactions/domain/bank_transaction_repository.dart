import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_detail.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';

abstract interface class BankTransactionRepository {
  /// [searchQuery], when non-empty, matches counterparty name, bank name,
  /// or reference number — a plain deterministic Postgres ILIKE, same
  /// rule as Vault's invoice search (spec §15). [periodStart]/[periodEnd]
  /// restrict to `transaction_date` in `[periodStart, periodEnd)` — used
  /// when a Reports period row is tapped to drill into its transactions.
  Future<Result<List<BankTransactionSummary>>> listTransactions({
    required String organizationId,
    required int offset,
    required int limit,
    String? searchQuery,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? verificationStatus,
  });

  /// Org-wide count of disputed transactions — see
  /// VaultRepository.countDisputed for why this is separate from the list.
  Future<Result<int>> countDisputed(String organizationId);

  Future<Result<BankTransactionDetail>> getDetail(String transactionId);

  /// Saves the user's corrections. Never touches verification_status —
  /// every scan is usable immediately on creation (needs_review), and only
  /// [rejectVerification] (admin/owner, enforced server-side by
  /// enforce_verification_status_change) moves it away from that.
  Future<Result<void>> saveDraftEdits({
    required String transactionId,
    required String direction,
    required double amount,
    required String transactionDate,
    required String counterpartyName,
    required String counterpartyAccount,
    required String bankName,
    required String referenceNumber,
    required String status,
  });

  /// Owner/admin only — disputes the transaction with an optional reason,
  /// which the submitter sees on their copy (and is notified of, via
  /// notify_bank_transaction_verification_decision). The submitter (or
  /// admin) then rescans it — see [deleteTransaction], which a rescan calls
  /// before capturing a fresh photo.
  Future<Result<void>> rejectVerification({
    required String transactionId,
    String? reason,
  });

  /// Permanently deletes the transaction, its scanned pages, and everything
  /// derived from it. Used both for an explicit user-initiated delete and
  /// as the first step of a rescan.
  Future<Result<void>> deleteTransaction(String transactionId);
}
