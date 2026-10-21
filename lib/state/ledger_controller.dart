import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';

class LedgerController extends ChangeNotifier {
  LedgerController(this._repository, this._sync);

  final LocalLedgerRepository _repository;
  final SyncTarget _sync;

  FarmLedger ledger = FarmLedger.empty;
  bool loading = false;
  String? error;
  String? notice;

  Future<void> load() async {
    loading = ledger.pendingCount == 0 && ledger.births.isEmpty;
    error = null;
    notifyListeners();
    try {
      ledger = await _repository.read();
      error = null;
    } on LedgerFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'The farm records on this phone could not be read.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> sync() async {
    try {
      final sent = await _repository.flush(_sync);
      ledger = await _repository.read();
      notice = sent == 0 ? null : 'Sent $sent records.';
      error = null;
    } on LedgerFailure catch (failure) {
      ledger = await _repository.read();
      error = failure.message;
    } catch (_) {
      error = 'Still offline. The record stays on this phone.';
    }
    notifyListeners();
  }

  Future<String?> addBirth(BirthRecord record) => _save(
    () => _repository.addBirth(record),
    empty: 'Enter the sow or cow tag.',
    invalid: record.damTag.trim().isEmpty || record.bornAlive < 0,
  );

  Future<String?> addDeath(DeathRecord record) => _save(
    () => _repository.addDeath(record),
    empty: 'Enter the animal tag.',
    invalid: record.animalTag.trim().isEmpty,
  );

  Future<String?> addFeedUse(FeedUse record) => _save(
    () => _repository.addFeedUse(record),
    empty: 'Choose how much feed was used.',
    invalid: record.quantityKg <= 0,
  );

  Future<String?> addPurchase(FeedPurchase record) => _save(
    () => _repository.addPurchase(record),
    empty: 'Enter the supplier and the cost.',
    invalid: record.supplier.trim().isEmpty || record.costCedis <= 0,
  );

  Future<String?> addBreeding(BreedingService record) => _save(
    () => _repository.addBreeding(record),
    empty: 'Enter the sow or cow tag.',
    invalid: record.damTag.trim().isEmpty,
  );

  Future<String?> addWeight(WeightRecord record) => _save(
    () => _repository.addWeight(record),
    empty: 'Enter the tag and the weight.',
    invalid: record.animalTag.trim().isEmpty || record.weightKg <= 0,
  );

  Future<String?> addHealth(HealthEvent record) => _save(
    () => _repository.addHealth(record),
    empty: 'Enter the animal tag.',
    invalid: record.animalTag.trim().isEmpty,
  );

  Future<String?> addExpense(ExpenseRecord record) {
    final problem = expenseProblem(record);
    if (problem != null) {
      error = problem;
      notifyListeners();
      return Future.value(problem);
    }
    return _save(
      () => _repository.addExpense(record),
      empty: 'Enter the amount in cedis.',
      invalid: false,
    );
  }

  Future<String?> addSale(SaleRecord record) => _save(
    () => _repository.addSale(record),
    empty: 'Enter the amount in cedis.',
    invalid: record.amountCedis <= 0,
  );

  Future<String?> addMilk(MilkYield record) => _save(
    () => _repository.addMilk(record),
    empty: 'Enter the cow tag.',
    invalid: record.cowTag.trim().isEmpty || record.litres <= 0,
  );

  Future<String?> _save(
    Future<void> Function() write, {
    required String empty,
    required bool invalid,
  }) async {
    if (invalid) {
      error = empty;
      notifyListeners();
      return empty;
    }
    try {
      await write();
      await sync();
      return null;
    } on LedgerFailure catch (failure) {
      error = failure.message;
      notifyListeners();
      return failure.message;
    } catch (_) {
      error = 'That record could not be saved.';
      notifyListeners();
      return error;
    }
  }
}
