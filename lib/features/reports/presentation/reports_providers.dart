import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/reports/data/report_export_service.dart';
import 'package:fbr_taxvault/features/reports/data/reports_repository_impl.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/reports_repository.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';

enum ReportView { byPeriod, bySupplier }

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepositoryImpl(ref.watch(supabaseClientProvider));
});

final reportExportServiceProvider = Provider<ReportExportService>((ref) {
  return ReportExportService(
    ref.watch(supabaseClientProvider),
    ref.watch(reportsRepositoryProvider),
  );
});

final selectedReportViewProvider = StateProvider<ReportView>(
  (ref) => ReportView.byPeriod,
);
final selectedPeriodTypeProvider = StateProvider<PeriodType>(
  (ref) => PeriodType.monthly,
);

/// Filters the already-fetched period/supplier lists client-side — both are
/// small aggregate lists (dozens of suppliers, at most a few dozen
/// periods), so there's no need for a round trip per keystroke.
final reportsSearchQueryProvider = StateProvider<String>((ref) => '');

final periodSummariesProvider = FutureProvider<List<PeriodSummary>>((
  ref,
) async {
  final org = ref.watch(currentOrganizationProvider);
  final periodType = ref.watch(selectedPeriodTypeProvider);
  if (org == null) return const [];

  final result = await ref
      .watch(reportsRepositoryProvider)
      .getPeriodSummaries(organizationId: org.id, periodType: periodType);
  return result.fold((summaries) => summaries, (failure) => throw failure);
});

final supplierSummariesProvider = FutureProvider<List<SupplierSummary>>((
  ref,
) async {
  final org = ref.watch(currentOrganizationProvider);
  if (org == null) return const [];

  final result = await ref
      .watch(reportsRepositoryProvider)
      .getSupplierSummaries(organizationId: org.id);
  return result.fold((summaries) => summaries, (failure) => throw failure);
});
