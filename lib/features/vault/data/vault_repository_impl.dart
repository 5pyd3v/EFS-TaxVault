import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_repository.dart';

class VaultRepositoryImpl implements VaultRepository {
  VaultRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<InvoiceSummary>>> listInvoices({
    required String organizationId,
    required VaultFilter filter,
    required VaultSort sort,
    required int offset,
    required int limit,
    String? searchQuery,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) async {
    try {
      var query = _client
          .from('invoices')
          .select(
            'id, invoice_number, invoice_date, total_amount, currency, document_type, verification_status, suppliers(name)',
          )
          .eq('organization_id', organizationId);

      final documentType = filter.documentType;
      if (documentType != null) {
        query = query.eq('document_type', documentType.value);
      }

      if (periodStart != null) {
        query = query.gte('invoice_date', _dateOnly(periodStart));
      }
      if (periodEnd != null) {
        query = query.lt('invoice_date', _dateOnly(periodEnd));
      }

      final trimmedQuery = searchQuery?.trim() ?? '';
      if (trimmedQuery.isNotEmpty) {
        final matchingSupplierIds = await _client
            .from('suppliers')
            .select('id')
            .eq('organization_id', organizationId)
            .ilike('name', '%$trimmedQuery%');
        final supplierIds = (matchingSupplierIds as List)
            .map((row) => (row as Map<String, dynamic>)['id'] as String)
            .toList();

        final orConditions = [
          'invoice_number.ilike.%$trimmedQuery%',
          if (supplierIds.isNotEmpty)
            'supplier_id.in.(${supplierIds.join(',')})',
        ];
        query = query.or(orConditions.join(','));
      }

      final rows = await query
          .order(sort.column, ascending: sort.ascending)
          .range(offset, offset + limit - 1);

      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(InvoiceSummary.fromMap)
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

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}
