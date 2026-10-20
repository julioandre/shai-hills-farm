import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAnimalRepository implements AnimalRepository {
  SupabaseAnimalRepository(this._client, {required this.userId});

  final SupabaseClient _client;
  final String? Function() userId;

  @override
  Future<List<Animal>> list() async {
    final id = _requireUser();
    try {
      final rows = await _client
          .from('animals')
          .select()
          .eq('user_id', id)
          .order('tag');
      return [
        for (final row in rows)
          Animal.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
    } catch (error) {
      throw RegisterFailure(registerErrorMessage(error));
    }
  }

  @override
  Future<Animal> save(Animal animal) async {
    final id = _requireUser();
    final trimmed = animal.tag.trim();
    if (trimmed.isEmpty) {
      throw const RegisterFailure('Enter a tag or ID.');
    }
    final stored = animal.tag == trimmed
        ? animal
        : animal.copyWith(tag: trimmed);
    try {
      final row = await _client
          .from('animals')
          .upsert(stored.toSupabaseRow(id))
          .select()
          .single();
      return Animal.fromJson(Map<String, dynamic>.from(row));
    } catch (error) {
      throw RegisterFailure(registerErrorMessage(error));
    }
  }

  @override
  Future<void> remove(String id) async {
    final user = _requireUser();
    try {
      await _client.from('animals').delete().eq('id', id).eq('user_id', user);
    } catch (error) {
      throw RegisterFailure(registerErrorMessage(error));
    }
  }

  String _requireUser() {
    final id = userId();
    if (id == null || id.isEmpty) {
      throw const RegisterFailure('Sign in before opening the register.');
    }
    return id;
  }
}

/// Turns a storage error into a sentence for the register screens.
String registerErrorMessage(Object error) {
  if (error is RegisterFailure) {
    return error.message;
  }
  if (error is PostgrestException) {
    final message = error.message.toLowerCase();
    if (error.code == '23505') {
      return 'That tag is already on the register.';
    }
    if (message.contains('animals') &&
        (message.contains('schema cache') ||
            message.contains('does not exist') ||
            error.code == '42P01')) {
      return 'The animals table is not in this Supabase project yet. '
          'Run supabase/migrations/20261020140000_animals.sql in the SQL editor.';
    }
    if (error.code == '42501' || message.contains('row-level security')) {
      return 'This account cannot change that animal.';
    }
    if (message.contains('jwt') || message.contains('expired')) {
      return 'The sign-in expired. Sign in again.';
    }
    return 'The register could not be saved.';
  }
  if (error is FormatException) {
    return 'An animal record could not be read.';
  }
  return 'The register could not be saved. Try again.';
}
