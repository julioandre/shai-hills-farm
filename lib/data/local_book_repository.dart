import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/book_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';

const _bookKey = 'shai_hills.book';

/// One farm book, shared by every signed-in person.
class LocalBookRepository implements BookRepository {
  LocalBookRepository({required this.store, required this.userId});

  final KeyValueStore store;
  final String? Function() userId;

  @override
  Future<List<FarmEntry>> list() async {
    _requireUser();
    return _merged(await _readAll());
  }

  @override
  Future<FarmEntry> save(FarmEntry entry) async {
    _requireUser();
    final note = entry.note.trim();
    if (note.isEmpty) {
      throw const BookFailure('Write a short note.');
    }
    final stored = entry.note == note ? entry : _withNote(entry, note);
    final book = [..._merged(await _readAll())];
    final index = book.indexWhere((other) => other.id == stored.id);
    if (index >= 0) {
      book[index] = stored;
    } else {
      book.add(stored);
    }
    await _writeAll({farmScopeKey: book});
    return stored;
  }

  @override
  Future<void> remove(String id) async {
    _requireUser();
    final book = [..._merged(await _readAll())];
    book.removeWhere((entry) => entry.id == id);
    await _writeAll({farmScopeKey: book});
  }

  List<FarmEntry> _merged(Map<String, List<FarmEntry>> all) {
    final byId = <String, FarmEntry>{};
    final keys = [
      for (final key in all.keys)
        if (key != farmScopeKey) key,
      if (all.containsKey(farmScopeKey)) farmScopeKey,
    ];
    for (final key in keys) {
      for (final entry in all[key] ?? const <FarmEntry>[]) {
        byId[entry.id] = entry;
      }
    }
    return byId.values.toList();
  }

  String _requireUser() {
    final id = userId();
    if (id == null || id.isEmpty) {
      throw const BookFailure('Sign in before opening the book.');
    }
    return id;
  }

  Future<Map<String, List<FarmEntry>>> _readAll() async {
    final raw = await store.read(_bookKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const BookFailure('The book on this device could not be read.');
    }
    final books = <String, List<FarmEntry>>{};
    for (final entry in decoded.entries) {
      final owner = entry.key;
      final rows = entry.value;
      if (owner is! String || rows is! List) {
        throw const BookFailure('The book on this device could not be read.');
      }
      books[owner] = [
        for (final row in rows)
          if (row is Map)
            FarmEntry.fromJson(Map<String, dynamic>.from(row))
          else
            throw const BookFailure(
              'The book on this device could not be read.',
            ),
      ];
    }
    return books;
  }

  Future<void> _writeAll(Map<String, List<FarmEntry>> books) async {
    final encoded = books.map(
      (owner, entries) =>
          MapEntry(owner, entries.map((entry) => entry.toLocalJson()).toList()),
    );
    await store.write(_bookKey, jsonEncode(encoded));
  }
}

FarmEntry _withNote(FarmEntry entry, String note) {
  return FarmEntry(
    id: entry.id,
    kind: entry.kind,
    happenedOn: entry.happenedOn,
    animalId: entry.animalId,
    animalTag: entry.animalTag,
    note: note,
    amount: entry.amount,
    updatedAt: entry.updatedAt,
  );
}
