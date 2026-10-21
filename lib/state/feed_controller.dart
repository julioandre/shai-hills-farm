import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/data/local_feed_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ids.dart';

class FeedController extends ChangeNotifier {
  FeedController(this._repository);

  final LocalFeedRepository _repository;

  FeedMill mill = FeedMill.empty;
  bool loading = false;
  String? error;

  Future<void> load() async {
    loading = mill.ingredients.isEmpty && mill.batches.isEmpty;
    error = null;
    notifyListeners();
    try {
      mill = await _repository.read();
      error = null;
    } on FeedFailure catch (failure) {
      error = failure.message;
    } catch (_) {
      error = 'The feed records on this phone could not be read.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String?> buy(FeedIngredient ingredient, DateTime today) {
    return _save((mill) => buyIngredient(mill, ingredient, today));
  }

  Future<String?> saveRecipe(FeedFormula formula) {
    return _save((mill) => saveFormula(mill, formula));
  }

  Future<String?> mix({
    required String formulaId,
    required double quantityKg,
    required DateTime producedOn,
    required String producedBy,
    required DateTime today,
  }) {
    return _save(
      (mill) => mixFeed(
        mill,
        id: newId(),
        number: 'FD-${mill.batches.length + 1}',
        formulaId: formulaId,
        quantityKg: quantityKg,
        producedOn: producedOn,
        producedBy: producedBy,
        today: today,
      ),
    );
  }

  Future<String?> give(FeedIssue issue, DateTime today) {
    return _save((mill) => giveFeed(mill, issue, today));
  }

  void clear() {
    mill = FeedMill.empty;
    loading = false;
    error = null;
    notifyListeners();
  }

  Future<String?> _save(FeedChange Function(FeedMill mill) change) async {
    final next = change(mill);
    if (next.error != null) {
      return next.error;
    }
    try {
      await _repository.write(next.mill);
      mill = next.mill;
      error = null;
      notifyListeners();
      return null;
    } on FeedFailure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'The feed records on this phone could not be saved.';
    }
  }
}
