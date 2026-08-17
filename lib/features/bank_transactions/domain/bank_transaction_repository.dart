import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_detail.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';

abstract interface class BankTransactionRepository {
  /// [searchQuery], when non-empty, matches counterparty name, bank name,
  /// or reference number — a plain deterministic Postgres ILIKE, same
  /// rule as Vault's invoice search (spec §15).
  Future<Result<List<BankTransactionSummary>>> listTransactions({
    required String organizationId,
    required int offset,
    required int limit,
    String? searchQuery,
  });

  Future<Result<BankTransactionDetail>> getDetail(String transactionId);

  Future<Result<void>> confirmVerification({
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

  /// Permanently deletes the transaction and its scanned pages. Used both
  /// for an explicit user-initiated delete and for discarding a
  /// transaction the user never confirmed.
  Future<Result<void>> deleteTransaction(String transactionId);
}
