import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:shai_hills_farm/domain/validation.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  FarmSession? session;
  bool restoring = true;
  bool busy = false;
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

  Future<bool> signIn(String email, String password) {
    return _submit(
      email: email,
      password: password,
      action: () => _repository.signIn(email: email, password: password),
    );
  }

  Future<bool> signUp(String email, String password) {
    return _submit(
      email: email,
      password: password,
      action: () => _repository.signUp(email: email, password: password),
    );
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
      busy = false;
      notice = null;
      notifyListeners();
    }
  }

  Future<bool> _submit({
    required String email,
    required String password,
    required Future<FarmSession> Function() action,
  }) async {
    final emailError = validateEmail(email);
    final passwordError = validatePassword(password);
    if (emailError != null || passwordError != null) {
      error = emailError ?? passwordError;
      notice = null;
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notice = null;
    notifyListeners();
    try {
      session = await action();
      return true;
    } on EmailConfirmationRequired catch (pending) {
      notice = pending.message;
      return false;
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
}
