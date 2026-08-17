import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/reports/domain/counterparty_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/period_type.dart';
import 'package:fbr_taxvault/features/reports/domain/reports_repository.dart';
import 'package:fbr_taxvault/features/reports/domain/supplier_summary.dart';
import 'package:fbr_taxvault/features/reports/domain/transaction_period_summary.dart';

class ReportsRepositoryImpl implements ReportsRepository {
  ReportsRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<PeriodSummary>>> getPeriodSummaries({
    required String organizationId,
    required PeriodType periodType,
  }) async {
    try {
      final rows = await _client.rpc(
        'get_period_summaries',
        params: {
          'p_organization_id': organizationId,
          'p_period_type': periodType.sqlValue,
        },
      );
      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(PeriodSummary.fromMap)
            .toList(),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<List<SupplierSummary>>> getSupplierSummaries({
    required String organizationId,
  }) async {
    try {
      final rows = await _client.rpc(
        'get_supplier_summaries',
        params: {'p_organization_id': organizationId},
      );
      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(SupplierSummary.fromMap)
            .toList(),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<List<TransactionPeriodSummary>>> getTransactionPeriodSummaries({
    required String organizationId,
    required PeriodType periodType,
  }) async {
    try {
      final rows = await _client.rpc(
        'get_bank_transaction_period_summaries',
        params: {
          'p_organization_id': organizationId,
          'p_period_type': periodType.sqlValue,
        },
      );
      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(TransactionPeriodSummary.fromMap)
            .toList(),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<List<CounterpartySummary>>> getCounterpartySummaries({
    required String organizationId,
  }) async {
    try {
      final rows = await _client.rpc(
        'get_bank_transaction_counterparty_summaries',
        params: {'p_organization_id': organizationId},
      );
      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(CounterpartySummary.fromMap)
            .toList(),
      );
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
