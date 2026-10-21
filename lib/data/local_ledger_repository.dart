import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';

const _ledgerKey = 'shai_hills.ledger';

/// Farm operations saved on the phone first.
///
/// Births, deaths, and feed are written here even with no network.
/// [flush] sends pending rows and marks only the ones the server accepted.
class LocalLedgerRepository {
  LocalLedgerRepository(this._store);

  final KeyValueStore _store;

  Future<FarmLedger> read() async {
    final raw = await _store.read(_ledgerKey);
    if (raw == null || raw.isEmpty) {
      return FarmLedger.empty;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const LedgerFailure(
        'The farm records on this phone could not be read.',
      );
    }
    return FarmLedger.fromJson(Map<String, dynamic>.from(decoded));
  }

  Future<void> addBirth(BirthRecord record) {
    return _add(
      (ledger) => FarmLedger(
        births: [...ledger.births, record],
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addDeath(DeathRecord record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: [...ledger.deaths, record],
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addFeedUse(FeedUse record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: [...ledger.feedUses, record],
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addPurchase(FeedPurchase record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: [...ledger.purchases, record],
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addBreeding(BreedingService record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: [...ledger.breeding, record],
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addWeight(WeightRecord record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: [...ledger.weights, record],
        health: ledger.health,
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addHealth(HealthEvent record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: [...ledger.health, record],
        sales: ledger.sales,
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addExpense(ExpenseRecord record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        expenses: [...ledger.expenses, record],
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addSale(SaleRecord record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: [...ledger.sales, record],
        expenses: ledger.expenses,
        milk: ledger.milk,
        land: ledger.land,
      ),
    );
  }

  Future<void> addMilk(MilkYield record) {
    return _add(
      (ledger) => FarmLedger(
        births: ledger.births,
        deaths: ledger.deaths,
        feedUses: ledger.feedUses,
        purchases: ledger.purchases,
        breeding: ledger.breeding,
        weights: ledger.weights,
        health: ledger.health,
        sales: ledger.sales,
        milk: [...ledger.milk, record],
        land: ledger.land,
      ),
    );
  }

  Future<void> replace(FarmLedger ledger) => _write(ledger);

  /// Returns how many rows were accepted. Stops at the first failure.
  Future<int> flush(SyncTarget target) async {
    final ledger = await read();
    final pending = pendingOps(ledger);
    final done = <String>{};
    try {
      for (final op in pending) {
        await target.push(op);
        final id = op.row['id'];
        if (id is String) {
          done.add(id);
        }
      }
    } on LedgerFailure {
      rethrow;
    } catch (_) {
      if (done.isEmpty) {
        throw const LedgerFailure(
          'Still offline. The record stays on this phone.',
        );
      }
    } finally {
      if (done.isNotEmpty) {
        await _write(markSynced(ledger, done));
      }
    }
    return done.length;
  }

  Future<void> _add(FarmLedger Function(FarmLedger ledger) change) async {
    final ledger = await read();
    await _write(change(ledger));
  }

  Future<void> _write(FarmLedger ledger) {
    return _store.write(_ledgerKey, jsonEncode(ledger.toJson()));
  }
}
