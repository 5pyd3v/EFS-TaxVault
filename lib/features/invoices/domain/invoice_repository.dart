import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';

abstract interface class InvoiceRepository {
  Future<Result<InvoiceDetail>> getInvoiceDetail(String invoiceId);

  /// Saves the user's corrections and marks the invoice verified. Totals
  /// are recomputed deterministically here — the same rule the Edge
  /// Function used (spec §8) — not trusted from user input either, only
  /// the individual amounts are.
  Future<Result<void>> confirmVerification({
    required String invoiceId,
    required String invoiceNumber,
    required String invoiceDate,
    required double subtotal,
    required double discount,
    required double salesTax,
    required double otherTaxes,
    required double totalAmount,
  });

  /// The canonical invoice JSON (spec §4), rebuilt from current database
  /// state every call — never a cached copy of what the AI first returned.
  /// This is NOT an FBR payload; it's the internal representation an
  /// FBRInvoicePayloadAdapter will consume once the official FBR schema
  /// exists (spec §5).
  Future<Result<Map<String, dynamic>>> getCanonicalJson(String invoiceId);

  /// Permanently deletes the invoice, its scanned pages, and everything
  /// derived from it (line items, warnings, FBR submissions). Used both for
  /// an explicit user-initiated delete and for discarding an invoice the
  /// user never confirmed.
  Future<Result<void>> deleteInvoice(String invoiceId);
}
