import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';

const _animalsKey = 'shai_hills.animals';

/// Animal register stored on this device, one herd per signed-in account.
class LocalAnimalRepository implements AnimalRepository {
  LocalAnimalRepository({required this.store, required this.userId});

  final KeyValueStore store;
  final String? Function() userId;

  @override
  Future<List<Animal>> list() async {
    final id = _requireUser();
    final all = await _readAll();
    return all[id] ?? [];
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
    final all = await _readAll();
    final herd = [...all[id] ?? <Animal>[]];
    final clash = herd.any(
      (other) =>
          other.id != stored.id &&
          other.tag.toLowerCase() == stored.tag.toLowerCase(),
    );
    if (clash) {
      throw RegisterFailure('Tag ${stored.tag} is already on the register.');
    }
    final index = herd.indexWhere((other) => other.id == stored.id);
    if (index >= 0) {
      herd[index] = stored;
    } else {
      herd.add(stored);
    }
    all[id] = herd;
    await _writeAll(all);
    return stored;
  }

  @override
  Future<void> remove(String id) async {
    final user = _requireUser();
    final all = await _readAll();
    final herd = [...all[user] ?? <Animal>[]];
    herd.removeWhere((animal) => animal.id == id);
    all[user] = herd;
    await _writeAll(all);
  }

  String _requireUser() {
    final id = userId();
    if (id == null || id.isEmpty) {
      throw const RegisterFailure('Sign in before opening the register.');
    }
    return id;
  }

  Future<Map<String, List<Animal>>> _readAll() async {
    final raw = await store.read(_animalsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const RegisterFailure('The on-device register could not be read.');
    }
    final herds = <String, List<Animal>>{};
    for (final entry in decoded.entries) {
      final owner = entry.key;
      final rows = entry.value;
      if (owner is! String || rows is! List) {
        throw const RegisterFailure(
          'The on-device register could not be read.',
        );
      }
      herds[owner] = [
        for (final row in rows)
          if (row is Map)
            Animal.fromJson(Map<String, dynamic>.from(row))
          else
            throw const RegisterFailure(
              'The on-device register could not be read.',
            ),
      ];
    }
    return herds;
  }

  Future<void> _writeAll(Map<String, List<Animal>> herds) async {
    final encoded = herds.map(
      (owner, animals) => MapEntry(
        owner,
        animals.map((animal) => animal.toLocalJson()).toList(),
      ),
    );
    await store.write(_animalsKey, jsonEncode(encoded));
  }
}
