import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/features/auth/domain/sign_up_outcome.dart';
import 'package:fbr_taxvault/features/auth/presentation/auth_providers.dart';

/// Drives sign-in/sign-up/sign-out. `state` is [AsyncLoading] while a
/// request is in flight and [AsyncError] holding a [Failure] on failure, so
/// screens can show inline error copy via `ref.listen`.
class AuthController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<bool> signIn({required String email, required String password}) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
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

  Future<bool> signInWithPin({
    required String phone,
    required String pin,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithPin(phone: phone, pin: pin);
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

  /// Returns the outcome so the screen can show the right success state
  /// (signed in vs. "check your email") — null means signUp failed and the
  /// error is already in `state` for `ref.listen` to pick up.
  Future<SignUpOutcome?> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = const AsyncLoading();
    final result = await ref
        .read(authRepositoryProvider)
        .signUp(email: email, password: password, fullName: fullName);
    return result.fold(
      (outcome) {
        state = const AsyncData(null);
        return outcome;
      },
      (failure) {
        state = AsyncError(failure, StackTrace.current);
        return null;
      },
    );
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    final result = await ref.read(authRepositoryProvider).signOut();
    state = result.fold(
      (_) => const AsyncData(null),
      (failure) => AsyncError(failure, StackTrace.current),
    );
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, void>(
  AuthController.new,
);
