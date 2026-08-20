import 'package:fbr_taxvault/features/auth/domain/app_user.dart';

/// What actually happened after a signUp call — previously this was
/// smuggled through the error channel (`Result.err(AuthFailure('Account
/// created. Please check your email...'))`), which meant "signup
/// succeeded" and "signup failed" were indistinguishable to the UI layer
/// and the sign-up screen had no success path to react to at all. This
/// project requires email confirmation (`mailer_autoconfirm: false`), so
/// [needsEmailConfirmation] is the outcome every real signup hits today;
/// [signedIn] exists for correctness if that project setting ever changes.
sealed class SignUpOutcome {
  const SignUpOutcome();
}

class SignedIn extends SignUpOutcome {
  const SignedIn(this.user);
  final AppUser user;
}

class NeedsEmailConfirmation extends SignUpOutcome {
  const NeedsEmailConfirmation();
}
