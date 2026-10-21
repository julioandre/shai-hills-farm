import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/sent_code.dart';
import 'package:shai_hills_farm/domain/session.dart';

/// Phone accounts. A text code signs the person in.
///
/// The on-device implementation keeps accounts on this device. The Supabase
/// implementation sends the code by text when a project is configured.
abstract interface class AuthRepository {
  FarmSession? get session;

  Future<FarmSession?> restore();

  Future<SentCode> sendCode({
    required String phone,
    required bool creating,
    String name = '',
  });

  Future<FarmSession> verifyCode({required String phone, required String code});

  Future<void> signOut();

  /// Everyone on this farm. An admin uses this to assign roles.
  Future<List<FarmPerson>> listPeople();

  /// Changes a person's role. Only an admin can call this.
  Future<void> assignRole({required String userId, required FarmRole role});

  /// Herds a worker may open. Empty means every herd. Only an admin can call this.
  Future<void> assignHerds({
    required String userId,
    required Set<Species> herds,
  });

  /// Saves the name shown when tasks are assigned.
  Future<void> setName({required String userId, required String name});
}
