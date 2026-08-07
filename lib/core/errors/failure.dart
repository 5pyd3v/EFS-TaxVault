/// Categorized failure reasons surfaced to the UI. Every failure carries a
/// user-safe [message] — never a raw exception or stack trace (spec: never
/// expose stack traces to users).
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection. Please try again.']);
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  /// Field name -> error message, for form-level display.
  final Map<String, String> fieldErrors;
}

final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Something went wrong on our end. Please try again.']);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'The requested item could not be found.']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
