import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_repository.dart';
import 'package:fbr_taxvault/features/dashboard/domain/dashboard_summary.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<DashboardSummary>> getSummary(String organizationId) async {
    try {
      final row = await _client
          .rpc(
            'get_dashboard_summary',
            params: {'p_organization_id': organizationId},
          )
          .single();
      return Result.ok(DashboardSummary.fromMap(row));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
