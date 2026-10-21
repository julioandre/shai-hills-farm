import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/session.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  FarmSession? session;
  bool restoring = true;
  bool busy = false;
  bool awaitingCode = false;
  String? error;
  String? notice;

  Future<void> restore() async {
    restoring = true;
    notifyListeners();
    try {
      session = await _repository.restore();
      error = null;
    } on AuthFailure catch (failure) {
      session = null;
      error = failure.message;
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<bool> sendCode(
    String phone, {
    required bool creating,
    String name = '',
  }) async {
    final phoneError = validatePhone(phone);
    if (phoneError != null) {
      error = phoneError;
      notice = null;
      awaitingCode = false;
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      final sent = await _repository.sendCode(
        phone: phone,
        creating: creating,
        name: name,
      );
      notice = sent.message;
      awaitingCode = true;
      return true;
    } on AuthFailure catch (failure) {
      error = failure.message;
      awaitingCode = false;
      return false;
    } catch (_) {
      error = 'That did not work. Try again.';
      awaitingCode = false;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyCode(String phone, String code) async {
    final phoneError = validatePhone(phone);
    final codeError = validateOtp(code);
    if (phoneError != null || codeError != null) {
      error = phoneError ?? codeError;
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      session = await _repository.verifyCode(phone: phone, code: code);
      awaitingCode = false;
      notice = null;
      return true;
    } on AuthFailure catch (failure) {
      error = failure.message;
      return false;
    } catch (_) {
      error = 'That did not work. Try again.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  void useDifferentNumber() {
    awaitingCode = false;
    error = null;
    notice = null;
    notifyListeners();
  }

  Future<List<FarmPerson>> listPeople() => _repository.listPeople();

  Future<String?> assignRole({
    required String userId,
    required FarmRole role,
  }) async {
    try {
      await _repository.assignRole(userId: userId, role: role);
      session = _repository.session;
      notifyListeners();
      return null;
    } on AuthFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'That role could not be saved.';
    }
  }

  Future<String?> assignHerds({
    required String userId,
    required Set<Species> herds,
  }) async {
    try {
      await _repository.assignHerds(userId: userId, herds: herds);
      session = _repository.session;
      notifyListeners();
      return null;
    } on AuthFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Those herds could not be saved.';
    }
  }

  Future<String?> setName({
    required String userId,
    required String name,
  }) async {
    try {
      await _repository.setName(userId: userId, name: name);
      return null;
    } on AuthFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'That name could not be saved.';
    }
  }

  Future<void> signOut() async {
    busy = true;
    notifyListeners();
    try {
      await _repository.signOut();
    } catch (_) {
      error = 'Signed out on this device.';
    } finally {
      session = null;
      awaitingCode = false;
      busy = false;
      notice = null;
      notifyListeners();
    }
  }
}
