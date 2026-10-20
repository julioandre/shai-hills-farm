import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:shai_hills_farm/domain/validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  FarmSession? get session => _sessionFromUser(_client.auth.currentUser);

  @override
  Future<FarmSession?> restore() async {
    return session;
  }

  @override
  Future<FarmSession> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: normalizeEmail(email),
        password: password,
      );
      final signedIn = _sessionFromUser(response.user);
      if (signedIn == null) {
        throw const AuthFailure('Sign-in did not return an account.');
      }
      return signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error));
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw const AuthFailure(
        'Could not reach Supabase. Check the connection and try again.',
      );
    }
  }

  @override
  Future<FarmSession> signUp({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeEmail(email);
    try {
      final response = await _client.auth.signUp(
        email: normalized,
        password: password,
      );
      final signedIn = _sessionFromUser(response.user);
      if (response.session == null || signedIn == null) {
        throw EmailConfirmationRequired(
          'Check $normalized for a confirmation message from Supabase, then sign in.',
        );
      }
      return signedIn;
    } on EmailConfirmationRequired {
      rethrow;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error));
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw const AuthFailure(
        'Could not reach Supabase. Check the connection and try again.',
      );
    }
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}

FarmSession? _sessionFromUser(User? user) {
  if (user == null) {
    return null;
  }
  final email = user.email;
  if (email == null || email.isEmpty) {
    return FarmSession(userId: user.id, email: 'Signed-in account');
  }
  return FarmSession(userId: user.id, email: email);
}

String _mapAuthMessage(AuthException error) {
  final message = error.message.toLowerCase();
  final code = error.code?.toLowerCase() ?? '';
  if (code == 'invalid_credentials' || message.contains('invalid login')) {
    return 'That email and password were not accepted.';
  }
  if (code == 'email_not_confirmed' ||
      message.contains('email not confirmed')) {
    return 'Confirm the email address, then sign in.';
  }
  if (code == 'user_already_exists' || message.contains('already registered')) {
    return 'An account with that email already exists. Sign in instead.';
  }
  if (message.contains('failed host lookup') ||
      message.contains('socket') ||
      message.contains('network')) {
    return 'Could not reach Supabase. Check the connection and try again.';
  }
  if (error.message.length < 180) {
    return error.message;
  }
  return 'Supabase rejected that sign-in. Try again.';
}
