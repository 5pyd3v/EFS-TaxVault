import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/app_user.dart';
import 'package:fbr_taxvault/features/auth/domain/auth_repository.dart';
import 'package:fbr_taxvault/features/auth/domain/sign_up_outcome.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
      );
      // `response.session` is the only reliable signal here — this project
      // requires email confirmation, and `response.user` can still come
      // back non-null (the account was created, just unconfirmed) even
      // when no session was established. Checking `user` instead of
      // `session` was the original bug: it meant a successful "check your
      // email" signup and a genuinely signed-in one were indistinguishable
      // to the UI, so the sign-up screen had no success state to show at
      // all — the user saw nothing happen and kept pressing the button,
      // which just resent the confirmation email until Supabase's rate
      // limit (2/hour on this project) kicked in.
      if (response.session == null) {
        return const Result.ok(NeedsEmailConfirmation());
      }
      final user = _mapUser(response.user);
      if (user == null) {
        return const Result.err(UnknownFailure());
      }
      return Result.ok(SignedIn(user));
    } on AuthException catch (e) {
      return Result.err(AuthFailure(e.message));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _mapUser(response.user);
      if (user == null) {
        return const Result.err(AuthFailure('Invalid email or password.'));
      }
      return Result.ok(user);
    } on AuthException catch (e) {
      return Result.err(AuthFailure(e.message));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<AppUser>> signInWithPin({
    required String phone,
    required String pin,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'login-with-pin',
        body: {'phone': phone, 'pin': pin},
      );
      final data = response.data as Map<String, dynamic>;
      final refreshToken = data['refresh_token'] as String;

      final authResponse = await _client.auth.setSession(refreshToken);
      final user = _mapUser(authResponse.user);
      if (user == null) {
        return const Result.err(
          AuthFailure('Could not sign in. Please try again.'),
        );
      }
      return Result.ok(user);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map && details['message'] is String
          ? details['message'] as String
          : 'Incorrect phone number or PIN.';
      return Result.err(AuthFailure(message));
    } on AuthException catch (e) {
      return Result.err(AuthFailure(e.message));
    } on SocketException {
      return const Result.err(NetworkFailure());
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Result.ok(null);
    } on AuthException catch (e) {
      return Result.err(AuthFailure(e.message));
    } catch (_) {
      return const Result.err(UnknownFailure());
    }
  }

  AppUser? _mapUser(User? user) {
    if (user == null || user.email == null) return null;
    return AppUser(
      id: user.id,
      email: user.email!,
      fullName: user.userMetadata?['full_name'] as String?,
      isPinManaged: user.userMetadata?['is_pin_managed'] == true,
    );
  }
}
