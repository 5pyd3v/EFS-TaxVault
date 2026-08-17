import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_detail.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_repository.dart';
import 'package:fbr_taxvault/features/bank_transactions/domain/bank_transaction_summary.dart';

class BankTransactionRepositoryImpl implements BankTransactionRepository {
  BankTransactionRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<BankTransactionSummary>>> listTransactions({
    required String organizationId,
    required int offset,
    required int limit,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('bank_transactions')
          .select(
            'id, direction, amount, currency, transaction_date, counterparty_name, bank_name, verification_status',
          )
          .eq('organization_id', organizationId);

      final trimmedQuery = searchQuery?.trim() ?? '';
      if (trimmedQuery.isNotEmpty) {
        query = query.or(
          [
            'counterparty_name.ilike.%$trimmedQuery%',
            'bank_name.ilike.%$trimmedQuery%',
            'reference_number.ilike.%$trimmedQuery%',
          ].join(','),
        );
      }

      final rows = await query
          .order('transaction_date', ascending: false)
          .range(offset, offset + limit - 1);

      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(BankTransactionSummary.fromMap)
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

  @override
  Future<Result<BankTransactionDetail>> getDetail(String transactionId) async {
    try {
      final row = await _client
          .from('bank_transactions')
          .select()
          .eq('id', transactionId)
          .single();
      return Result.ok(BankTransactionDetail.fromMap(row));
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
    required String transactionId,
    required String direction,
    required double amount,
    required String transactionDate,
    required String counterpartyName,
    required String counterpartyAccount,
    required String bankName,
    required String referenceNumber,
    required String status,
  }) async {
    try {
      await _client
          .from('bank_transactions')
          .update({
            'direction': direction,
            'amount': _round2(amount),
            'transaction_date': transactionDate.isEmpty
                ? null
                : transactionDate,
            'counterparty_name': counterpartyName,
            'counterparty_account': counterpartyAccount,
            'bank_name': bankName,
            'reference_number': referenceNumber,
            'status': status,
            'verification_status': 'verified',
            'verified_by': _client.auth.currentUser!.id,
            'verified_at': DateTime.now().toIso8601String(),
          })
          .eq('id', transactionId);

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

  @override
  Future<Result<void>> deleteTransaction(String transactionId) async {
    try {
      final transaction = await _client
          .from('bank_transactions')
          .select('documents(storage_path, page_count)')
          .eq('id', transactionId)
          .maybeSingle();
      final document = transaction?['documents'] as Map<String, dynamic>?;
      final storagePath = document?['storage_path'] as String?;
      final pageCount = (document?['page_count'] as num?)?.toInt() ?? 0;

      if (storagePath != null && storagePath.isNotEmpty && pageCount > 0) {
        try {
          await _client.storage.from('documents').remove([
            for (var i = 1; i <= pageCount; i++) '$storagePath/page_$i.jpg',
          ]);
        } on StorageException {
          // Best-effort: an orphaned storage object is recoverable later;
          // leaving the DB row behind because of a storage hiccup isn't.
        }
      }

      await _client.rpc(
        'delete_bank_transaction',
        params: {'p_transaction_id': transactionId},
      );
      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }
}
