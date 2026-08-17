import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';

/// Merges invoices and bank transactions into one date-ordered feed for the
/// Dashboard's "Recent activity" section — the two source lists (see
/// `recentActivityProvider`) have different shapes, so this wraps whichever
/// one a given row actually is rather than forcing them into a single
/// artificial model.
sealed class RecentActivityItem {
  const RecentActivityItem();

  DateTime? get date;
}

class RecentInvoiceActivity extends RecentActivityItem {
  const RecentInvoiceActivity(this.invoice);

  final InvoiceSummary invoice;

  @override
  DateTime? get date => invoice.invoiceDate;
}

class RecentBankTransactionActivity extends RecentActivityItem {
  const RecentBankTransactionActivity(this.transaction);

  final BankTransactionSummary transaction;

  @override
  DateTime? get date => transaction.transactionDate;
}
