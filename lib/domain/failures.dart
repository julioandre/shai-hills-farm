/// A sign-in problem the screen can show as written.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Supabase created the user and is waiting for the confirmation email.
class EmailConfirmationRequired implements Exception {
  const EmailConfirmationRequired(this.message);

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
