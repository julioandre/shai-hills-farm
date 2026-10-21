/// A sign-in problem the screen can show as written.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A register read or write the screen can show as written.
class RegisterFailure implements Exception {
  const RegisterFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A farm-book read or write the screen can show as written.
class BookFailure implements Exception {
  const BookFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A ledger or sync problem the screen can show as written.
class LedgerFailure implements Exception {
  const LedgerFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A feed-mill read or write the screen can show as written.
class FeedFailure implements Exception {
  const FeedFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
