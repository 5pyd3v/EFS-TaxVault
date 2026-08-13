import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/shared/widgets/empty_state.dart';

/// Wraps [AsyncValue.when] with the app's standard loading/error visuals so
/// every screen doesn't hand-roll its own spinner and error copy.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.errorTitle = 'Something went wrong',
    this.errorMessage = 'Please check your connection and try again.',
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final WidgetBuilder? loading;
  final String errorTitle;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () =>
          loading?.call(context) ??
          const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => EmptyState(
        icon: Icons.error_outline_rounded,
        title: errorTitle,
        message: errorMessage,
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      ),
    );
  }
}
