import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/reports/domain/counterparty_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/transaction_period_summary.dart';

abstract interface class ReportsRepository {
  Future<Result<List<PeriodSummary>>> getPeriodSummaries({
    required String organizationId,
    required PeriodType periodType,
  });

  Future<Result<List<SupplierSummary>>> getSupplierSummaries({
    required String organizationId,
  });

  Future<Result<List<TransactionPeriodSummary>>> getTransactionPeriodSummaries({
    required String organizationId,
    required PeriodType periodType,
  });

  Future<Result<List<CounterpartySummary>>> getCounterpartySummaries({
    required String organizationId,
  });
}
