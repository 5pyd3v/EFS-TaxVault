import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/network/supabase_providers.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';
import 'package:fbr_taxvault/features/notifications/data/notifications_repository_impl.dart';
import 'package:fbr_taxvault/features/notifications/domain/app_notification.dart';
import 'package:fbr_taxvault/features/notifications/domain/notifications_repository.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  return NotificationsRepositoryImpl(ref.watch(supabaseClientProvider));
});

/// Both providers below watch `currentUserProvider` even though the
/// repository already scopes its queries by the signed-in user — without
/// that reactive dependency, these plain `FutureProvider`s never rebuild
/// when the user changes, so switching accounts in the same app session
/// (or a stale first-load before auth resolves) would keep showing
/// whichever user's notifications loaded first.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;

  final result = await ref.watch(notificationsRepositoryProvider).unreadCount();
  return result.fold((count) => count, (failure) => throw failure);
});

final notificationsListProvider = FutureProvider<List<AppNotification>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];

  final result = await ref.watch(notificationsRepositoryProvider).list();
  return result.fold((items) => items, (failure) => throw failure);
});
