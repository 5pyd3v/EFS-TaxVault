import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/features/dashboard/presentation/dashboard_providers.dart';
import 'package:fbr_taxvault/features/reports/presentation/reports_providers.dart';
import 'package:fbr_taxvault/features/vault/presentation/vault_controller.dart';

/// Call after any invoice mutation (verify, delete, discard) so every
/// screen that summarizes invoices — Dashboard, Reports, Vault — reflects
/// the change immediately. Without this, each of those screens' data stays
/// cached until the user manually pulls to refresh, which reads as a bug
/// (a deleted invoice still shows in "Recent invoices", stale counts on
/// the dashboard) rather than the app just not having re-fetched yet.
void refreshInvoiceDependentState(WidgetRef ref) {
  ref.invalidate(dashboardSummaryProvider);
  ref.invalidate(recentInvoicesProvider);
  ref.invalidate(monthlyTaxTrendProvider);
  ref.invalidate(periodSummariesProvider);
  ref.invalidate(supplierSummariesProvider);
  ref.read(vaultControllerProvider.notifier).refresh();
}
