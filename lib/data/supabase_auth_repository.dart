import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/limits.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/sent_code.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;
  FarmRole _role = FarmRole.worker;
  Set<Species> _herds = const {};

  @override
  FarmSession? get session =>
      _sessionFromUser(_client.auth.currentUser, _role, _herds);

  @override
  Future<FarmSession?> restore() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _role = FarmRole.worker;
      _herds = const {};
      return null;
    }
    final loaded = await _loadProfile(user.id);
    _role = loaded.role;
    _herds = loaded.herds;
    return session;
  }

  @override
  Future<SentCode> sendCode({
    required String phone,
    required bool creating,
    String name = '',
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw const AuthFailure(
        'Enter the phone number you use, like $phoneHint.',
      );
    }
    if (creating) {
      await _ensureRoom();
    }
    try {
      await _client.auth.signInWithOtp(
        phone: normalized,
        shouldCreateUser: creating,
      );
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error, creating: creating));
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw const AuthFailure(
        'Could not reach Supabase. Check the connection and try again.',
      );
    }
    final shown = displayPhone(normalized);
    return SentCode(
      message: 'A code was sent by text to $shown. Enter the 6 digits.',
    );
  }

  @override
  Future<FarmSession> verifyCode({
    required String phone,
    required String code,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw const AuthFailure(
        'Enter the phone number you use, like $phoneHint.',
      );
    }
    try {
      final response = await _client.auth.verifyOTP(
        phone: normalized,
        token: otpDigits(code),
        type: OtpType.sms,
      );
      if (response.user == null) {
        throw const AuthFailure(
          'That code was not accepted. Tap Send code again.',
        );
      }
      final loaded = await _loadProfile(response.user!.id);
      _role = loaded.role;
      _herds = loaded.herds;
      final signedIn = session;
      if (signedIn == null) {
        throw const AuthFailure(
          'That code was not accepted. Tap Send code again.',
        );
      }
      return signedIn;
    } on AuthException catch (error) {
      throw AuthFailure(_mapAuthMessage(error, creating: false));
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
  Future<void> signOut() async {
    await _client.auth.signOut();
    _role = FarmRole.worker;
    _herds = const {};
  }

  @override
  Future<List<FarmPerson>> listPeople() async {
    try {
      return await _readPeople('user_id, phone, role, herds, display_name');
    } catch (_) {
      try {
        return await _readPeople('user_id, phone, role, herds');
      } catch (_) {
        try {
          return await _readPeople('user_id, phone, role');
        } catch (_) {
          throw const AuthFailure(
            'People are not set up yet. Run the latest SQL migration.',
          );
        }
      }
    }
  }

  Future<List<FarmPerson>> _readPeople(String columns) async {
    final rows = await _client.from('profiles').select(columns);
    return [
      for (final row in rows)
        FarmPerson(
          userId: row['user_id'] as String,
          phone: (row['phone'] as String?) ?? '',
          role: FarmRole.parse(row['role'] as String),
          name: (row['display_name'] as String?) ?? '',
          herds: _herdsFrom(row['herds']),
        ),
    ];
  }

  @override
  Future<void> assignRole({
    required String userId,
    required FarmRole role,
  }) async {
    if (_role != FarmRole.admin) {
      throw const AuthFailure('Only an admin can change roles.');
    }
    try {
      await _client
          .from('profiles')
          .update({'role': role.wire})
          .eq('user_id', userId);
      if (_client.auth.currentUser?.id == userId) {
        _role = role;
      }
    } catch (_) {
      throw const AuthFailure('That role could not be saved.');
    }
  }

  @override
  Future<void> assignHerds({
    required String userId,
    required Set<Species> herds,
  }) async {
    if (_role != FarmRole.admin) {
      throw const AuthFailure('Only an admin can change roles.');
    }
    try {
      await _client
          .from('profiles')
          .update({
            'herds': [for (final species in herds) species.wire],
          })
          .eq('user_id', userId);
      if (_client.auth.currentUser?.id == userId) {
        _herds = herds;
      }
    } catch (_) {
      throw const AuthFailure(
        'Those herds could not be saved. Add a herds column on profiles.',
      );
    }
  }

  @override
  Future<void> setName({required String userId, required String name}) async {
    final current = _client.auth.currentUser;
    if (current == null) {
      throw const AuthFailure('Sign in before saving a name.');
    }
    if (_role != FarmRole.admin && current.id != userId) {
      throw const AuthFailure('Only an admin can change another person.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Enter a name.');
    }
    try {
      await _client
          .from('profiles')
          .update({'display_name': trimmed})
          .eq('user_id', userId);
    } catch (_) {
      throw const AuthFailure(
        'That name could not be saved. Add a display_name column on profiles.',
      );
    }
  }

  Future<({FarmRole role, Set<Species> herds})> _loadProfile(
    String userId,
  ) async {
    try {
      final row = await _client
          .from('profiles')
          .select('role, herds')
          .eq('user_id', userId)
          .maybeSingle();
      return _profileFrom(row);
    } catch (_) {
      try {
        final row = await _client
            .from('profiles')
            .select('role')
            .eq('user_id', userId)
            .maybeSingle();
        return _profileFrom(row);
      } catch (_) {
        return (role: FarmRole.worker, herds: const <Species>{});
      }
    }
  }

  ({FarmRole role, Set<Species> herds}) _profileFrom(
    Map<String, dynamic>? row,
  ) {
    final role = row?['role'];
    return (
      role: role is String ? FarmRole.parse(role) : FarmRole.worker,
      herds: _herdsFrom(row?['herds']),
    );
  }

  Future<void> _ensureRoom() async {
    try {
      final room = await _client.rpc('farm_has_room');
      if (room == false) {
        throw const AuthFailure(farmUserLimitMessage);
      }
    } on AuthFailure {
      rethrow;
    } catch (_) {
      // An older database without this function still enforces the cap
      // with the trigger in the farm book migration.
    }
  }
}

FarmSession? _sessionFromUser(User? user, FarmRole role, Set<Species> herds) {
  if (user == null) {
    return null;
  }
  final phone = user.phone;
  if (phone == null || phone.isEmpty) {
    return FarmSession(
      userId: user.id,
      phone: 'Signed-in account',
      role: role,
      herds: herds,
    );
  }
  return FarmSession(userId: user.id, phone: phone, role: role, herds: herds);
}

Set<Species> _herdsFrom(Object? raw) {
  if (raw is! List) {
    return const {};
  }
  return {
    for (final item in raw)
      if (item is String) Species.parse(item),
  };
}

String _mapAuthMessage(AuthException error, {required bool creating}) {
  final message = error.message.toLowerCase();
  final code = error.code?.toLowerCase() ?? '';
  if (message.contains('8 people')) {
    return farmUserLimitMessage;
  }
  if (code == 'otp_expired' || message.contains('expired')) {
    return 'That code has expired. Tap Send code again.';
  }
  if (code == 'otp_disabled' || message.contains('otp')) {
    if (message.contains('invalid') || message.contains('token')) {
      return 'That code is not right. Check the text and try again.';
    }
  }
  if (message.contains('invalid') &&
      (message.contains('otp') || message.contains('token'))) {
    return 'That code is not right. Check the text and try again.';
  }
  if (message.contains('signups not allowed') ||
      message.contains('user not found') ||
      code == 'user_not_found') {
    return 'This number is not on the farm yet. Choose I am new here.';
  }
  if (creating &&
      (code == 'user_already_exists' || message.contains('already'))) {
    return 'This number already works here. Sign in instead.';
  }
  if (message.contains('phone provider') ||
      message.contains('unsupported phone') ||
      message.contains('phone')) {
    if (message.contains('not enabled') || message.contains('disabled')) {
      return 'Text codes are not turned on for this farm yet.';
    }
  }
  if (message.contains('failed host lookup') ||
      message.contains('socket') ||
      message.contains('network')) {
    return 'Could not reach Supabase. Check the connection and try again.';
  }
  if (error.message.length < 180) {
    return error.message;
  }
  return 'That did not work. Try again.';
}
