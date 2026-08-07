import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_repository.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  InvoiceRepositoryImpl(this._client);

  final SupabaseClient _client;

  static const double _calculationTolerance = 1.0;

  @override
  Future<Result<InvoiceDetail>> getInvoiceDetail(String invoiceId) async {
    try {
      final results = await Future.wait([
        _client.from('invoices').select('*, suppliers(name)').eq('id', invoiceId).single(),
        _client.from('invoice_items').select().eq('invoice_id', invoiceId).order('line_no'),
        _client
            .from('ai_warnings')
            .select('severity, message')
            .eq('invoice_id', invoiceId)
            .eq('resolved', false),
      ]);

      final invoice = results[0] as Map<String, dynamic>;
      final items = (results[1] as List).cast<Map<String, dynamic>>();
      final warnings = (results[2] as List).cast<Map<String, dynamic>>();
      final supplier = invoice['suppliers'] as Map<String, dynamic>?;

      return Result.ok(InvoiceDetail.fromMap(
        invoice,
        items: items,
        warnings: warnings,
        supplierName: supplier?['name'] as String? ?? '',
      ));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> confirmVerification({
    required String invoiceId,
    required String invoiceNumber,
    required String invoiceDate,
    required double subtotal,
    required double discount,
    required double salesTax,
    required double otherTaxes,
    required double totalAmount,
  }) async {
    try {
      final taxableAmount = _round2(subtotal - discount);
      final expectedTotal = _round2(taxableAmount + salesTax + otherTaxes);
      final calculationMismatch = (expectedTotal - totalAmount).abs() > _calculationTolerance;

      await _client.from('invoices').update({
        'invoice_number': invoiceNumber,
        'invoice_date': invoiceDate,
        'subtotal': _round2(subtotal),
        'discount': _round2(discount),
        'taxable_amount': taxableAmount,
        'sales_tax': _round2(salesTax),
        'other_taxes': _round2(otherTaxes),
        'total_amount': _round2(totalAmount),
        'calculation_mismatch': calculationMismatch,
        'verification_status': 'verified',
        'verified_by': _client.auth.currentUser!.id,
        'verified_at': DateTime.now().toIso8601String(),
      }).eq('id', invoiceId);

      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  double _round2(double value) => (value * 100).round() / 100;
}
