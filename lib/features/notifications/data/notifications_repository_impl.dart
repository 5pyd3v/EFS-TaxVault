import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/notifications/domain/app_notification.dart';
import 'package:fbr_taxvault/features/notifications/domain/notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl(this._client);

  final SupabaseClient _client;

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<Result<List<AppNotification>>> list({int limit = 50}) async {
    final userId = _userId;
    if (userId == null) return const Result.ok([]);
    try {
      final rows = await _client
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return Result.ok(
        (rows as List)
            .cast<Map<String, dynamic>>()
            .map(AppNotification.fromMap)
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
  Future<Result<int>> unreadCount() async {
    final userId = _userId;
    if (userId == null) return const Result.ok(0);
    try {
      final response = await _client
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .isFilter('read_at', null)
          .count(CountOption.exact);
      return Result.ok(response.count);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> markRead(String notificationId) async {
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> markAllRead() async {
    final userId = _userId;
    if (userId == null) return const Result.ok(null);
    try {
      await _client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
      return const Result.ok(null);
    } on SocketException {
      return const Result.err(NetworkFailure());
    } on PostgrestException catch (e) {
      return Result.err(ServerFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> delete(String notificationId) async {
    try {
      await _client.from('notifications').delete().eq('id', notificationId);
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
