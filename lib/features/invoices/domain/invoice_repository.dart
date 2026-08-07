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
}
