import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';

abstract interface class DashboardRepository {
  Future<Result<DashboardSummary>> getSummary(String organizationId);
}
