import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/data/supabase_book_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/book_repository.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/validation.dart';

class BookController extends ChangeNotifier {
  BookController(this._repository);

  final BookRepository _repository;

  List<FarmEntry> entries = [];
  bool loading = false;
  String? error;
  String? refreshError;

  int _epoch = 0;
  int _loadTicket = 0;

  Future<void> load({bool refresh = false}) async {
    final epoch = _epoch;
    final ticket = ++_loadTicket;
    if (!refresh) {
      loading = true;
      error = null;
      notifyListeners();
    }
    try {
      final rows = sortEntries(await _repository.list());
      if (epoch != _epoch || ticket != _loadTicket) {
        return;
      }
      entries = rows;
      error = null;
      refreshError = null;
    } catch (caught) {
      if (epoch != _epoch || ticket != _loadTicket) {
        return;
      }
      final message = bookErrorMessage(caught);
      if (entries.isEmpty) {
        error = message;
      } else {
        refreshError = message;
      }
    } finally {
      if (epoch == _epoch && ticket == _loadTicket) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<String?> save(
    FarmEntry entry, {
    required DateTime today,
    Animal? animal,
  }) async {
    final message = validateEntry(
      kind: entry.kind,
      happenedOn: entry.happenedOn,
      note: entry.note,
      amountText: entry.amount?.toString() ?? '',
      animal: animal,
      today: today,
    );
    if (message != null) {
      return message;
    }
    _epoch++;
    try {
      final saved = await _repository.save(entry);
      entries = sortEntries([
        ...entries.where((item) => item.id != saved.id),
        saved,
      ]);
      error = null;
      refreshError = null;
      notifyListeners();
      return null;
    } catch (caught) {
      return bookErrorMessage(caught);
    }
  }

  Future<String?> remove(String id) async {
    _epoch++;
    try {
      await _repository.remove(id);
      entries = entries.where((entry) => entry.id != id).toList();
      error = null;
      refreshError = null;
      notifyListeners();
      return null;
    } catch (caught) {
      return bookErrorMessage(caught);
    }
  }

  void clear() {
    _epoch++;
    _loadTicket++;
    entries = [];
    loading = false;
    error = null;
    refreshError = null;
    notifyListeners();
  }
}
