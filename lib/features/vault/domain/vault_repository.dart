import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';

abstract interface class VaultRepository {
  Future<Result<List<InvoiceSummary>>> listInvoices({
    required String organizationId,
    required VaultFilter filter,
    required VaultSort sort,
    required int offset,
    required int limit,
  });
}
