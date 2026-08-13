import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/vault/domain/invoice_summary.dart';
import 'package:fbr_taxvault/features/vault/domain/vault_filter.dart';

abstract interface class VaultRepository {
  /// [searchQuery], when non-empty, matches invoice number or supplier name
  /// — a plain deterministic Postgres ILIKE, not sent to Gemini (spec §15:
  /// "Do NOT send every search query to Gemini"). [periodStart]/[periodEnd]
  /// restrict to `invoice_date` in `[periodStart, periodEnd)` — used when a
  /// Reports period row is tapped to drill into its invoices.
  Future<Result<List<InvoiceSummary>>> listInvoices({
    required String organizationId,
    required VaultFilter filter,
    required VaultSort sort,
    required int offset,
    required int limit,
    String? searchQuery,
    DateTime? periodStart,
    DateTime? periodEnd,
  });
}
