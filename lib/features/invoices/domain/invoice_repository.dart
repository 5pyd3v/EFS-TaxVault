import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';

abstract interface class InvoiceRepository {
  Future<Result<InvoiceDetail>> getInvoiceDetail(String invoiceId);

  /// Saves the user's corrections. Totals are recomputed deterministically
  /// here — the same rule the Edge Function used (spec §8) — not trusted
  /// from user input either, only the individual amounts are. Never
  /// touches verification_status — every scan is usable immediately on
  /// creation (needs_review), and only [rejectVerification] (admin/owner,
  /// enforced server-side by enforce_verification_status_change) moves it
  /// away from that.
  Future<Result<void>> saveDraftEdits({
    required String invoiceId,
    required String invoiceNumber,
    required String invoiceDate,
    required double subtotal,
    required double discount,
    required double salesTax,
    required double otherTaxes,
    required double totalAmount,
  });

  /// Owner/admin only — disputes the invoice with an optional reason, which
  /// the submitter sees on their copy (and is notified of, via
  /// notify_invoice_verification_decision). The submitter (or admin) then
  /// rescans it — see [deleteInvoice], which a rescan calls before
  /// capturing a fresh photo.
  Future<Result<void>> rejectVerification({
    required String invoiceId,
    String? reason,
  });

  /// The canonical invoice JSON (spec §4), rebuilt from current database
  /// state every call — never a cached copy of what the AI first returned.
  /// This is NOT an FBR payload; it's the internal representation an
  /// FBRInvoicePayloadAdapter will consume once the official FBR schema
  /// exists (spec §5).
  Future<Result<Map<String, dynamic>>> getCanonicalJson(String invoiceId);

  /// Permanently deletes the invoice, its scanned pages, and everything
  /// derived from it (line items, warnings, FBR submissions). Used both for
  /// an explicit user-initiated delete and as the first step of a rescan.
  Future<Result<void>> deleteInvoice(String invoiceId);
}
