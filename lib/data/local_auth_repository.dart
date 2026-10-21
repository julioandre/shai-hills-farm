import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/sent_code.dart';
import 'package:shai_hills_farm/domain/session.dart';

const _usersKey = 'shai_hills.auth.users';
const _sessionKey = 'shai_hills.auth.session';
const _codesKey = 'shai_hills.auth.codes';

const _codeLifetime = Duration(minutes: 5);
const _maxAttempts = 5;

/// Phone accounts kept on this device.
///
/// A code is created when someone asks for one. Until a text service is
/// connected, the code is also shown on the sign-in screen. The practice
/// admin and the practice worker always receive 123456.
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
        _session = FarmSession(
          userId: entry.value.id,
          phone: entry.key,
          role: entry.value.role,
          herds: entry.value.herds,
        );
        return _session;
      }
    }
    await _store.write(_sessionKey, null);
    _session = null;
    return null;
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
    final users = await _readUsers();
    final existing = users.containsKey(normalized);
    if (creating && existing) {
      throw const AuthFailure(
        'This number already works here. Sign in instead.',
      );
    }
    if (!creating && !existing) {
      throw const AuthFailure(
        'This number is not on the farm yet. Choose I am new here.',
      );
    }
    final practice = normalized == demoPhone || normalized == workerPhone;
    final code = practice ? demoOtp : _newCode();
    final salt = _newSalt();
    final pending = _PendingCode(
      salt: salt,
      codeHash: _hashCode(salt, code),
      expiresAt: DateTime.now().toUtc().add(_codeLifetime),
      creating: creating,
      attempts: 0,
      name: creating ? name.trim() : '',
    );
    final codes = await _readCodes();
    codes[normalized] = pending;
    await _writeCodes(codes);
    final shown = displayPhone(normalized);
    final message = practice
        ? 'A code was sent to $shown. Practice code: $demoOtp.'
        : 'A code was sent to $shown. Your code is $code. It works for 5 minutes.';
    return SentCode(message: message, previewCode: code);
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
    final digits = otpDigits(code);
    final codes = await _readCodes();
    final pending = codes[normalized];
    if (pending == null) {
      throw const AuthFailure('Tap Send code first.');
    }
    if (DateTime.now().toUtc().isAfter(pending.expiresAt)) {
      codes.remove(normalized);
      await _writeCodes(codes);
      throw const AuthFailure('That code has expired. Tap Send code again.');
    }
    if (pending.codeHash != _hashCode(pending.salt, digits)) {
      final attempts = pending.attempts + 1;
      if (attempts >= _maxAttempts) {
        codes.remove(normalized);
        await _writeCodes(codes);
        throw const AuthFailure('Too many tries. Tap Send code again.');
      }
      codes[normalized] = pending.withAttempts(attempts);
      await _writeCodes(codes);
      throw const AuthFailure(
        'That code is not right. Check the text and try again.',
      );
    }
    final users = await _readUsers();
    final account = pending.creating
        ? await _createAccount(users, normalized, name: pending.name)
        : users[normalized];
    if (account == null) {
      throw const AuthFailure(
        'This number is not on the farm yet. Choose I am new here.',
      );
    }
    codes.remove(normalized);
    await _writeCodes(codes);
    await _store.write(_sessionKey, account.id);
    _session = FarmSession(
      userId: account.id,
      phone: normalized,
      role: account.role,
      herds: account.herds,
    );
    return _session!;
  }

  Future<_LocalAccount> _createAccount(
    Map<String, _LocalAccount> users,
    String phone, {
    String name = '',
  }) async {
    if (users.containsKey(phone)) {
      throw const AuthFailure(
        'This number already works here. Sign in instead.',
      );
    }
    final account = _LocalAccount(
      id: switch (phone) {
        demoPhone => demoUserId,
        workerPhone => workerUserId,
        _ => newId(),
      },
      role: phone == demoPhone ? FarmRole.admin : FarmRole.worker,
      herds: phone == workerPhone ? const {Species.pig} : const {},
      name: name,
    );
    users[phone] = account;
    await _writeUsers(users);
    return account;
  }

  @override
  Future<List<FarmPerson>> listPeople() async {
    final users = await _readUsers();
    final people = [
      for (final entry in users.entries)
        FarmPerson(
          userId: entry.value.id,
          phone: entry.key,
          role: entry.value.role,
          name: entry.value.name,
          herds: entry.value.herds,
        ),
    ];
    people.sort((a, b) => a.phone.compareTo(b.phone));
    return people;
  }

  @override
  Future<void> assignRole({
    required String userId,
    required FarmRole role,
  }) async {
    final current = _session;
    if (current == null || current.role != FarmRole.admin) {
      throw const AuthFailure('Only an admin can change roles.');
    }
    final users = await _readUsers();
    String? phone;
    for (final entry in users.entries) {
      if (entry.value.id == userId) {
        phone = entry.key;
      }
    }
    if (phone == null) {
      throw const AuthFailure('That person is not on the farm.');
    }
    final account = users[phone]!;
    if (account.role == FarmRole.admin && role != FarmRole.admin) {
      final admins = users.values.where((row) => row.role == FarmRole.admin);
      if (admins.length <= 1) {
        throw const AuthFailure('The farm needs one admin.');
      }
    }
    users[phone] = _LocalAccount(
      id: account.id,
      role: role,
      herds: account.herds,
      name: account.name,
    );
    await _writeUsers(users);
    if (current.userId == userId) {
      _session = FarmSession(
        userId: current.userId,
        phone: current.phone,
        role: role,
        herds: account.herds,
      );
    }
  }

  @override
  Future<void> assignHerds({
    required String userId,
    required Set<Species> herds,
  }) async {
    final current = _session;
    if (current == null || current.role != FarmRole.admin) {
      throw const AuthFailure('Only an admin can change roles.');
    }
    final users = await _readUsers();
    String? phone;
    for (final entry in users.entries) {
      if (entry.value.id == userId) {
        phone = entry.key;
      }
    }
    if (phone == null) {
      throw const AuthFailure('That person is not on the farm.');
    }
    final account = users[phone]!;
    if (account.role == FarmRole.admin) {
      throw const AuthFailure('The admin looks after every animal.');
    }
    users[phone] = _LocalAccount(
      id: account.id,
      role: account.role,
      herds: herds,
      name: account.name,
    );
    await _writeUsers(users);
    if (current.userId == userId) {
      _session = FarmSession(
        userId: current.userId,
        phone: current.phone,
        role: current.role,
        herds: herds,
      );
    }
  }

  @override
  Future<void> setName({required String userId, required String name}) async {
    final current = _session;
    if (current == null) {
      throw const AuthFailure('Sign in before saving a name.');
    }
    if (current.role != FarmRole.admin && current.userId != userId) {
      throw const AuthFailure('Only an admin can change another person.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const AuthFailure('Enter a name.');
    }
    final users = await _readUsers();
    String? phone;
    for (final entry in users.entries) {
      if (entry.value.id == userId) {
        phone = entry.key;
      }
    }
    if (phone == null) {
      throw const AuthFailure('That person is not on the farm.');
    }
    final account = users[phone]!;
    users[phone] = _LocalAccount(
      id: account.id,
      role: account.role,
      herds: account.herds,
      herdsSpecified: account.herdsSpecified,
      name: trimmed,
    );
    await _writeUsers(users);
  }

  @override
  Future<void> signOut() async {
    await _store.write(_sessionKey, null);
    _session = null;
  }

  Future<Map<String, _LocalAccount>> _readUsers() async {
    final users = <String, _LocalAccount>{};
    final raw = await _store.read(_usersKey);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const AuthFailure(
          'Saved accounts on this device could not be read.',
        );
      }
      for (final entry in decoded.entries) {
        final phone = entry.key;
        final value = entry.value;
        if (phone is! String || value is! Map) {
          throw const AuthFailure(
            'Saved accounts on this device could not be read.',
          );
        }
        users[phone] = _LocalAccount.fromJson(Map<String, dynamic>.from(value));
      }
    }
    final demo = users[demoPhone];
    if (demo == null) {
      users[demoPhone] = const _LocalAccount(
        id: demoUserId,
        role: FarmRole.admin,
      );
      await _writeUsers(users);
    } else if (demo.role != FarmRole.admin && demo.id == demoUserId) {
      users[demoPhone] = const _LocalAccount(
        id: demoUserId,
        role: FarmRole.admin,
      );
      await _writeUsers(users);
    }
    final worker = users[workerPhone];
    if (worker == null) {
      users[workerPhone] = const _LocalAccount(
        id: workerUserId,
        role: FarmRole.worker,
        herds: {Species.pig},
      );
      await _writeUsers(users);
    } else if (!worker.herdsSpecified && worker.id == workerUserId) {
      users[workerPhone] = _LocalAccount(
        id: worker.id,
        role: worker.role,
        herds: const {Species.pig},
        name: worker.name,
      );
      await _writeUsers(users);
    }
    var named = false;
    for (final entry in {demoPhone: 'Kofi', workerPhone: 'Ama'}.entries) {
      final account = users[entry.key];
      if (account != null && account.name.trim().isEmpty) {
        users[entry.key] = _LocalAccount(
          id: account.id,
          role: account.role,
          herds: account.herds,
          herdsSpecified: account.herdsSpecified,
          name: entry.value,
        );
        named = true;
      }
    }
    if (named) {
      await _writeUsers(users);
    }
    return users;
  }

  Future<void> _writeUsers(Map<String, _LocalAccount> users) async {
    final encoded = users.map(
      (phone, account) => MapEntry(phone, account.toJson()),
    );
    await _store.write(_usersKey, jsonEncode(encoded));
  }

  Future<Map<String, _PendingCode>> _readCodes() async {
    final raw = await _store.read(_codesKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return {};
    }
    final codes = <String, _PendingCode>{};
    for (final entry in decoded.entries) {
      final phone = entry.key;
      final value = entry.value;
      if (phone is String && value is Map) {
        codes[phone] = _PendingCode.fromJson(Map<String, dynamic>.from(value));
      }
    }
    return codes;
  }

  Future<void> _writeCodes(Map<String, _PendingCode> codes) async {
    final encoded = codes.map(
      (phone, pending) => MapEntry(phone, pending.toJson()),
    );
    await _store.write(_codesKey, jsonEncode(encoded));
  }
}

class _LocalAccount {
  const _LocalAccount({
    required this.id,
    required this.role,
    this.herds = const {},
    this.herdsSpecified = true,
    this.name = '',
  });

  final String id;
  final FarmRole role;
  final Set<Species> herds;
  final bool herdsSpecified;
  final String name;

  factory _LocalAccount.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const AuthFailure(
        'Saved accounts on this device could not be read.',
      );
    }
    final role = json['role'];
    final rawHerds = json['herds'];
    final herds = <Species>{
      if (rawHerds is List)
        for (final item in rawHerds)
          if (item is String) Species.parse(item),
    };
    return _LocalAccount(
      id: id,
      role: role is String
          ? FarmRole.parse(role)
          : id == demoUserId
          ? FarmRole.admin
          : FarmRole.worker,
      herds: herds,
      herdsSpecified: rawHerds is List,
      name: json['name'] is String ? json['name'] as String : '',
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'role': role.wire,
    'name': name,
    'herds': [for (final species in herds) species.wire],
  };
}

class _PendingCode {
  const _PendingCode({
    required this.salt,
    required this.codeHash,
    required this.expiresAt,
    required this.creating,
    required this.attempts,
    this.name = '',
  });

  final String salt;
  final String codeHash;
  final DateTime expiresAt;
  final bool creating;
  final int attempts;
  final String name;

  _PendingCode withAttempts(int attempts) {
    return _PendingCode(
      salt: salt,
      codeHash: codeHash,
      expiresAt: expiresAt,
      creating: creating,
      attempts: attempts,
      name: name,
    );
  }

  factory _PendingCode.fromJson(Map<String, dynamic> json) {
    final salt = json['salt'];
    final codeHash = json['codeHash'];
    final expiresAt = json['expiresAt'];
    final creating = json['creating'];
    final attempts = json['attempts'];
    if (salt is! String ||
        codeHash is! String ||
        expiresAt is! String ||
        creating is! bool) {
      throw const AuthFailure('The sign-in code could not be read.');
    }
    return _PendingCode(
      salt: salt,
      codeHash: codeHash,
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      creating: creating,
      attempts: attempts is int ? attempts : 0,
      name: json['name'] is String ? json['name'] as String : '',
    );
  }

  Map<String, Object> toJson() {
    return {
      'salt': salt,
      'codeHash': codeHash,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'creating': creating,
      'attempts': attempts,
      'name': name,
    };
  }
}

String _hashCode(String salt, String code) {
  return sha256.convert(utf8.encode('$salt:$code')).toString();
}

String _newSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64UrlEncode(bytes);
}

String _newCode() {
  final random = Random.secure();
  return List.generate(6, (_) => random.nextInt(10)).join();
}
