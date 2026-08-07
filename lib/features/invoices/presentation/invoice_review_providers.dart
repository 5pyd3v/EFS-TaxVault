import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/invoices/data/invoice_repository_impl.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_detail.dart';
import 'package:fbr_taxvault/features/invoices/domain/invoice_repository.dart';

final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  return InvoiceRepositoryImpl(ref.watch(supabaseClientProvider));
});

final invoiceDetailProvider = FutureProvider.family<InvoiceDetail, String>((ref, invoiceId) async {
  final result = await ref.watch(invoiceRepositoryProvider).getInvoiceDetail(invoiceId);
  return result.fold((detail) => detail, (failure) => throw failure);
});
