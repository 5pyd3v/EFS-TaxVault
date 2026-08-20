import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/features/auth/domain/organization.dart';
import 'package:fbr_taxvault/features/team/domain/team_member.dart';
import 'package:fbr_taxvault/features/team/presentation/team_providers.dart';

/// Drives every team-management mutation. `state` is [AsyncLoading] while a
/// request is in flight and [AsyncError] holding a [Failure] on failure, so
/// screens can show inline error copy via `ref.listen` — same shape as
/// [AuthController].
class TeamController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<NewTeamMemberCredentials?> createMember({
    required String organizationId,
    required String fullName,
    required String phone,
    required OrganizationRole role,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(teamRepositoryProvider)
        .createMember(
          organizationId: organizationId,
          fullName: fullName,
          phone: phone,
          role: role,
        );
    return result.fold(
      (credentials) {
        state = const AsyncData(null);
        ref.invalidate(teamMembersProvider);
        return credentials;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
    );
  }

  Future<String?> regeneratePin({
    required String userId,
    required String organizationId,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(teamRepositoryProvider)
        .regeneratePin(userId: userId, organizationId: organizationId);
    return result.fold(
      (pin) {
        state = const AsyncData(null);
        return pin;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
    );
  }

  Future<bool> removeMember({
    required String userId,
    required String organizationId,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(teamRepositoryProvider)
        .removeMember(userId: userId, organizationId: organizationId);
    return result.fold(
      (_) {
        state = const AsyncData(null);
        ref.invalidate(teamMembersProvider);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }

  Future<bool> setMemberGeminiKey({
    required String userId,
    required String organizationId,
    required String apiKey,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(teamRepositoryProvider)
        .setMemberGeminiKey(
          userId: userId,
          organizationId: organizationId,
          apiKey: apiKey,
        );
    return result.fold(
      (_) {
        state = const AsyncData(null);
        return true;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return false;
      },
    );
  }
}

final teamControllerProvider = AsyncNotifierProvider<TeamController, void>(
  TeamController.new,
);
