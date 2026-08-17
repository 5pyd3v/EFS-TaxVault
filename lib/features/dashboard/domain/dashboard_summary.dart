/// All figures are computed by the `get_dashboard_summary` Postgres
/// function (supabase/migrations/0010_dashboard_functions.sql,
/// 0023_bank_transaction_reports.sql) — never by the client — so the
/// numbers a user sees always match what reports will later show.
class DashboardSummary {
  const DashboardSummary({
    required this.totalInvoices,
    required this.currentMonthInvoices,
    required this.pendingVerification,
    required this.potentialIssues,
    required this.totalBankTransactions,
    required this.currentMonthBankTransactions,
  });

  final int totalInvoices;
  final int currentMonthInvoices;
  final int pendingVerification;
  final int potentialIssues;
  final int totalBankTransactions;
  final int currentMonthBankTransactions;

  int get currentMonthDocuments =>
      currentMonthInvoices + currentMonthBankTransactions;

  factory DashboardSummary.empty() => const DashboardSummary(
    totalInvoices: 0,
    currentMonthInvoices: 0,
    pendingVerification: 0,
    potentialIssues: 0,
    totalBankTransactions: 0,
    currentMonthBankTransactions: 0,
  );

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalInvoices: (map['total_invoices'] as num?)?.toInt() ?? 0,
      currentMonthInvoices:
          (map['current_month_invoices'] as num?)?.toInt() ?? 0,
      pendingVerification: (map['pending_verification'] as num?)?.toInt() ?? 0,
      potentialIssues: (map['potential_issues'] as num?)?.toInt() ?? 0,
      totalBankTransactions:
          (map['total_bank_transactions'] as num?)?.toInt() ?? 0,
      currentMonthBankTransactions:
          (map['current_month_bank_transactions'] as num?)?.toInt() ?? 0,
    );
  }
}
