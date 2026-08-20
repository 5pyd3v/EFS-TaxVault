import 'package:fbr_taxvault/core/errors/result.dart';
import 'package:fbr_taxvault/features/auth/domain/app_user.dart';
import 'package:fbr_taxvault/features/auth/domain/sign_up_outcome.dart';

abstract interface class AuthRepository {
  AppUser? get currentUser;

  Future<Result<SignUpOutcome>> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<Result<AppUser>> signIn({
    required String email,
    required String password,
  });

  /// Signs in a business team member via the login-with-pin Edge Function
  /// (phone + PIN only, no email/password for these accounts — see
  /// create-team-member and 0025_team_pin_credentials.sql).
  Future<Result<AppUser>> signInWithPin({
    required String phone,
    required String pin,
  });

  Future<Result<void>> signOut();
}
