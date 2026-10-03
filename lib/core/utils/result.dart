sealed class AppResult<T> {
  const AppResult();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(Failure<T> failure) failure,
  }) {
    final self = this;
    if (self is Success<T>) return success(self.data);
    return failure(self as Failure<T>);
  }

  T? get dataOrNull => switch (this) {
        Success<T>(:final data) => data,
        Failure<T>() => null,
      };

  Failure<T>? get failureOrNull => switch (this) {
        Success<T>() => null,
        Failure<T>() => this as Failure<T>,
      };
}

final class Success<T> extends AppResult<T> {
  final T data;

  const Success(this.data);
}

final class Failure<T> extends AppResult<T> {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => 'Failure($code: $message)';
}

AppResult<T> success<T>(T data) => Success<T>(data);

AppResult<T> failure<T>(String message, {String? code}) =>
    Failure<T>(message, code: code);

String describeDatabaseError(Object error, String fallback) {
  final text = error.toString().trim();
  if (text.isEmpty) return fallback;
  if (text == 'DatabaseException') return fallback;
  return text;
}
