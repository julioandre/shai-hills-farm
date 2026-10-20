import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:shai_hills_farm/domain/validation.dart';

const _usersKey = 'shai_hills.auth.users';
const _sessionKey = 'shai_hills.auth.session';

/// Email and password accounts kept on this device.
///
/// Passwords are stored as a salted hash. This is the mock used when
/// SUPABASE_URL and SUPABASE_ANON_KEY are not set. It is not a second
/// security boundary for a shared server.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  final KeyValueStore _store;

  FarmSession? _session;

  @override
  FarmSession? get session => _session;

  @override
  Future<FarmSession?> restore() async {
    final userId = await _store.read(_sessionKey);
    if (userId == null || userId.isEmpty) {
      _session = null;
      return null;
    }
    final users = await _readUsers();
    for (final entry in users.entries) {
      if (entry.value.id == userId) {
        _session = FarmSession(userId: entry.value.id, email: entry.key);
        return _session;
      }
    }
    await _store.write(_sessionKey, null);
    _session = null;
    return null;
  }

  @override
  Future<FarmSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeEmail(email);
    final users = await _readUsers();
    final account = users[normalized];
    if (account == null ||
        account.passwordHash != _hashPassword(account.salt, password)) {
      throw const AuthFailure(
        'That email and password do not match an account on this device.',
      );
    }
    await _store.write(_sessionKey, account.id);
    _session = FarmSession(userId: account.id, email: normalized);
    return _session!;
  }

  @override
  Future<FarmSession> signUp({
    required String email,
    required String password,
  }) async {
    final normalized = normalizeEmail(email);
    final users = await _readUsers();
    if (users.containsKey(normalized)) {
      throw const AuthFailure(
        'An account with that email is already on this device. Sign in instead.',
      );
    }
    final salt = _newSalt();
    final account = _LocalAccount(
      id: newId(),
      salt: salt,
      passwordHash: _hashPassword(salt, password),
    );
    users[normalized] = account;
    await _writeUsers(users);
    await _store.write(_sessionKey, account.id);
    _session = FarmSession(userId: account.id, email: normalized);
    return _session!;
  }

  @override
  Future<void> signOut() async {
    await _store.write(_sessionKey, null);
    _session = null;
  }

  Future<Map<String, _LocalAccount>> _readUsers() async {
    final raw = await _store.read(_usersKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const AuthFailure(
        'Saved accounts on this device could not be read.',
      );
    }
    final users = <String, _LocalAccount>{};
    for (final entry in decoded.entries) {
      final email = entry.key;
      final value = entry.value;
      if (email is! String || value is! Map) {
        throw const AuthFailure(
          'Saved accounts on this device could not be read.',
        );
      }
      users[email] = _LocalAccount.fromJson(Map<String, dynamic>.from(value));
    }
    return users;
  }

  Future<void> _writeUsers(Map<String, _LocalAccount> users) async {
    final encoded = users.map(
      (email, account) => MapEntry(email, account.toJson()),
    );
    await _store.write(_usersKey, jsonEncode(encoded));
  }
}

class _LocalAccount {
  const _LocalAccount({
    required this.id,
    required this.salt,
    required this.passwordHash,
  });

  final String id;
  final String salt;
  final String passwordHash;

  factory _LocalAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final salt = json['salt'];
    final passwordHash = json['passwordHash'];
    if (id is! String || salt is! String || passwordHash is! String) {
      throw const AuthFailure(
        'Saved accounts on this device could not be read.',
      );
    }
    return _LocalAccount(id: id, salt: salt, passwordHash: passwordHash);
  }

  Map<String, String> toJson() {
    return {'id': id, 'salt': salt, 'passwordHash': passwordHash};
  }
}

String _hashPassword(String salt, String password) {
  return sha256.convert(utf8.encode('$salt:$password')).toString();
}

String _newSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}
