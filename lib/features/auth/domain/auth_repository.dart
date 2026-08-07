import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/app_user.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}
