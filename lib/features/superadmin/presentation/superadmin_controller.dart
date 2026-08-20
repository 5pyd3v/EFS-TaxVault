import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/features/superadmin/domain/platform_organization.dart';
import 'package:fbr_taxvault/features/superadmin/presentation/superadmin_providers.dart';

/// Drives every superadmin mutation. `state` is [AsyncLoading] while a
/// request is in flight and [AsyncError] holding a [Failure] on failure —
/// same shape as [AuthController]/[TeamController].
class SuperadminController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> setBlocked({
    required String organizationId,
    required bool blocked,
    String? reason,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(superadminRepositoryProvider)
        .setBlocked(
          organizationId: organizationId,
          blocked: blocked,
          reason: reason,
        );
    return result.fold(
      (_) {
        state = const AsyncData(null);
        ref.invalidate(allOrganizationsProvider);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<NewSandboxCredentials?> createSandboxAccount({
    required String fullName,
    required String organizationName,
    String? email,
    String? geminiApiKey,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(superadminRepositoryProvider)
        .createSandboxAccount(
          fullName: fullName,
          organizationName: organizationName,
          email: email,
          geminiApiKey: geminiApiKey,
        );
    return result.fold(
      (credentials) {
        state = const AsyncData(null);
        ref.invalidate(allOrganizationsProvider);
        return credentials;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
    );
  }

  Future<bool> deleteIncompleteSignup(String userId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(superadminRepositoryProvider)
        .deleteIncompleteSignup(userId);
    return result.fold(
      (_) {
        state = const AsyncData(null);
        ref.invalidate(incompleteSignupsProvider);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> deleteOrganization(String organizationId) async {
    state = const AsyncLoading();
    final result = await ref
        .read(superadminRepositoryProvider)
        .deleteOrganization(organizationId);
    return result.fold(
      (_) {
        state = const AsyncData(null);
        ref.invalidate(allOrganizationsProvider);
        ref.invalidate(incompleteSignupsProvider);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }
}

final superadminControllerProvider =
    AsyncNotifierProvider<SuperadminController, void>(SuperadminController.new);
