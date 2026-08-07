import 'package:fbr_taxvault/core/errors/failure.dart';

/// A lightweight `Result<T>` for repository/use-case boundaries, so callers
/// handle failures explicitly instead of relying on try/catch leaking
/// implementation-specific exceptions up through the layers.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) {
    final self = this;
    return switch (self) {
      Ok<T>() => onOk(self.value),
      Err<T>() => onErr(self.failure),
    };
  }

  Result<R> map<R>(R Function(T value) transform) {
    final self = this;
    return switch (self) {
      Ok<T>() => Result.ok(transform(self.value)),
      Err<T>() => Result.err(self.failure),
    };
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
