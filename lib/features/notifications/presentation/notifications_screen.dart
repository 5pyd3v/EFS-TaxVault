import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fbr_taxvault/core/router/app_routes.dart';
import 'package:fbr_taxvault/core/theme/app_spacing.dart';
import 'package:fbr_taxvault/features/notifications/domain/app_notification.dart';
import 'package:fbr_taxvault/features/notifications/presentation/notifications_providers.dart';
import 'package:fbr_taxvault/shared/widgets/async_value_view.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';
import 'package:fbr_taxvault/shared/widgets/icon_chip.dart';

final _dateFormat = DateFormat('d MMM, h:mm a');

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Swiped-away notification ids, removed from view the instant the swipe
  // completes — before the delete network call even starts. This is what
  // actually fixes the crash: Dismissible removes itself from the widget
  // tree as soon as its dismiss animation finishes, but the OLD code only
  // removed the item from the underlying list after `await delete()` +
  // `ref.invalidate()` resolved. Swipe a second item (or anything else that
  // rebuilds the list) during that network round-trip and Flutter tries to
  // rebuild a Dismissible with a key it already tore down — "A dismissed
  // Dismissible widget is still part of the tree." Filtering locally,
  // synchronously, closes that window entirely regardless of network speed.
  final _locallyDismissedIds = <String>{};

  Future<void> _delete(String id) async {
    final result = await ref.read(notificationsRepositoryProvider).delete(id);
    if (!mounted) return;
    result.fold(
      (_) {
        ref.invalidate(notificationsListProvider);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      (failure) {
        // Delete failed server-side — put it back rather than leaving the
        // notification permanently (but only visually) gone.
        setState(() => _locallyDismissedIds.remove(id));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsListProvider);
              ref.invalidate(unreadNotificationsCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsListProvider),
        child: AsyncValueView<List<AppNotification>>(
          value: notificationsAsync,
          onRetry: () => ref.invalidate(notificationsListProvider),
          data: (allNotifications) {
            final notifications = allNotifications
                .where((n) => !_locallyDismissedIds.contains(n.id))
                .toList();
            if (notifications.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: AppSpacing.giant),
                  EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'No notifications',
                    message:
                        "You'll see updates about invoices that need attention here.",
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _NotificationTile(
                notification: notifications[index],
                onDismissed: () {
                  final id = notifications[index].id;
                  setState(() => _locallyDismissedIds.add(id));
                  _delete(id);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({
    required this.notification,
    required this.onDismissed,
  });

  final AppNotification notification;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final icon = switch (notification.type) {
      'calculation_mismatch' => Icons.calculate_outlined,
      'extraction_failed' => Icons.error_outline_rounded,
      'invoice_verified' ||
      'bank_transaction_verified' => Icons.check_circle_outline_rounded,
      'invoice_rejected' ||
      'bank_transaction_rejected' => Icons.cancel_outlined,
      _ => Icons.notifications_outlined,
    };

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: theme.colorScheme.error,
        ),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          if (notification.isUnread) {
            await ref
                .read(notificationsRepositoryProvider)
                .markRead(notification.id);
            ref.invalidate(notificationsListProvider);
            ref.invalidate(unreadNotificationsCountProvider);
          }
          if (!context.mounted) return;
          final invoiceId = notification.invoiceId;
          final transactionId = notification.transactionId;
          if (invoiceId != null) {
            context.push(AppRoutes.invoiceReview(invoiceId));
          } else if (transactionId != null) {
            context.push(AppRoutes.bankTransactionReview(transactionId));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: notification.isUnread
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : theme.colorScheme.surface,
            border: Border.all(
              color: notification.isUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.3)
                  : theme.colorScheme.outline,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconChip(icon: icon, color: theme.colorScheme.primary, size: 34),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: theme.textTheme.titleSmall),
                    if (notification.body != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        notification.body!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(notification.createdAt.toLocal()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (notification.isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
