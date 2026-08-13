/// All figures are computed by the `get_dashboard_summary` Postgres
/// function (supabase/migrations/0010_dashboard_functions.sql) — never by
/// the client — so the numbers a user sees always match what reports and
/// tax calculations will later show.
class DashboardSummary {
  const DashboardSummary({
    required this.totalInvoices,
    required this.currentMonthInvoices,
    required this.currentMonthTaxAmount,
    required this.pendingVerification,
    required this.potentialIssues,
  });

  final int totalInvoices;
  final int currentMonthInvoices;
  final double currentMonthTaxAmount;
  final int pendingVerification;
  final int potentialIssues;

  factory DashboardSummary.empty() => const DashboardSummary(
    totalInvoices: 0,
    currentMonthInvoices: 0,
    currentMonthTaxAmount: 0,
    pendingVerification: 0,
    potentialIssues: 0,
  );

  factory DashboardSummary.fromMap(Map<String, dynamic> map) {
    return DashboardSummary(
      totalInvoices: (map['total_invoices'] as num?)?.toInt() ?? 0,
      currentMonthInvoices:
          (map['current_month_invoices'] as num?)?.toInt() ?? 0,
      currentMonthTaxAmount:
          (map['current_month_tax_amount'] as num?)?.toDouble() ?? 0,
      pendingVerification: (map['pending_verification'] as num?)?.toInt() ?? 0,
      potentialIssues: (map['potential_issues'] as num?)?.toInt() ?? 0,
    );
  }
}
