import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/notifications/domain/app_notification.dart';

abstract interface class NotificationsRepository {
  Future<Result<List<AppNotification>>> list({int limit = 50});
  Future<Result<int>> unreadCount();
  Future<Result<void>> markRead(String notificationId);
  Future<Result<void>> markAllRead();
  Future<Result<void>> delete(String notificationId);
}
