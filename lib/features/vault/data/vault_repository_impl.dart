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

      final rows = await query
          .order(sort.column, ascending: sort.ascending)
          .range(offset, offset + limit - 1);

      return Result.ok((rows as List).cast<Map<String, dynamic>>().map(InvoiceSummary.fromMap).toList());
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
