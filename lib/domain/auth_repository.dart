import 'package:shai_hills_farm/domain/session.dart';

/// Email and password accounts.
///
/// The on-device implementation stores them on this device. The Supabase
/// implementation uses Supabase Auth when a project is configured.
abstract interface class AuthRepository {
  FarmSession? get session;

  Future<FarmSession?> restore();

  Future<FarmSession> signIn({required String email, required String password});

  Future<FarmSession> signUp({required String email, required String password});

  Future<void> signOut();
}
