import 'package:shai_hills_farm/domain/book_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBookRepository implements BookRepository {
  SupabaseBookRepository(this._client, {required this.userId});

  final SupabaseClient _client;
  final String? Function() userId;

  @override
  Future<List<FarmEntry>> list() async {
    _requireUser();
    try {
      final rows = await _client
          .from('farm_entries')
          .select()
          .order('happened_on', ascending: false);
      return [
        for (final row in rows)
          FarmEntry.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (error) {
      throw BookFailure(bookErrorMessage(error));
    }
  }

  @override
  Future<FarmEntry> save(FarmEntry entry) async {
    final id = _requireUser();
    final note = entry.note.trim();
    if (note.isEmpty) {
      throw const BookFailure('Write a short note.');
    }
    final stored = entry.note == note ? entry : _withNote(entry, note);
    try {
      final row = await _client
          .from('farm_entries')
          .upsert(stored.toSupabaseRow(id))
          .select()
          .single();
      return FarmEntry.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      throw BookFailure(bookErrorMessage(error));
    }
  }

  @override
  Future<void> remove(String id) async {
    _requireUser();
    try {
      await _client.from('farm_entries').delete().eq('id', id);
    } catch (error) {
      throw BookFailure(bookErrorMessage(error));
    }
  }

  String _requireUser() {
    final id = userId();
    if (id == null || id.isEmpty) {
      throw const BookFailure('Sign in before opening the book.');
    }
    return id;
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

/// Turns a storage error into a sentence for the book screens.
String bookErrorMessage(Object error) {
  if (error is BookFailure) {
    return error.message;
  }
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (message.contains('farm_entries') &&
        (message.contains('schema cache') ||
            message.contains('does not exist') ||
            error.code == '42P01' ||
            error.code == 'PGRST205')) {
      return 'The farm book is not in this Supabase project yet. '
          'Run supabase/migrations/20261020180000_farm_book.sql in the SQL editor.';
    }
    if (error.code == '23503') {
      return 'Choose an animal that is still on the register.';
    }
    if (error.code == '23514') {
      return 'That note could not be saved. Check the litres, cedis, and the animal.';
    }
    if (error.code == '42501' || message.contains('row-level security')) {
      return 'This account cannot change that note.';
    }
    if (message.contains('jwt') || message.contains('expired')) {
      return 'The sign-in expired. Sign in again.';
    }
    return 'The book could not be saved.';
  }
  if (error is FormatException) {
    return 'A note in the book could not be read.';
  }
  return 'The book could not be saved. Try again.';
}
