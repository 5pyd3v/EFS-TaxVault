import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fbr_taxvault/core/errors/failure.dart';
import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/app_user.dart';
import 'package:fbr_taxvault/features/auth/domain/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  @override
  AppUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Future<Result<AppUser>> signUp({
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
      final user = _mapUser(response.user);
      if (user == null) {
        return const Result.err(
          AuthFailure('Account created. Please check your email to confirm before signing in.'),
        );
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
    );
  }
}
