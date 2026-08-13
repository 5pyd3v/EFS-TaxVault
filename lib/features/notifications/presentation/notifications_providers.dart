import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/notifications/data/notifications_repository_impl.dart';
import 'package:fbr_taxvault/features/notifications/domain/app_notification.dart';
import 'package:fbr_taxvault/features/notifications/domain/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(ref.watch(supabaseClientProvider));
});

final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final result = await ref.watch(notificationsRepositoryProvider).unreadCount();
  return result.fold((count) => count, (failure) => throw failure);
});

final notificationsListProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final result = await ref.watch(notificationsRepositoryProvider).list();
  return result.fold((items) => items, (failure) => throw failure);
});
