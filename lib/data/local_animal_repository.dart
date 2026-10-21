import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';

const _animalsKey = 'shai_hills.animals';

/// One animal register for the farm, shared by every signed-in person.
class LocalAnimalRepository implements AnimalRepository {
  LocalAnimalRepository({required this.store, required this.userId});

  final KeyValueStore store;
  final String? Function() userId;

  @override
  Future<List<Animal>> list() async {
    _requireUser();
    return _merged(await _readAll());
  }

  @override
  Future<Animal> save(Animal animal) async {
    _requireUser();
    final trimmed = animal.tag.trim();
    if (trimmed.isEmpty) {
      throw const RegisterFailure('Enter a tag or ID.');
    }
    final stored = animal.tag == trimmed
        ? animal
        : animal.copyWith(tag: trimmed);
    final herd = [..._merged(await _readAll())];
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
    await _writeAll({farmScopeKey: herd});
    return stored;
  }

  /// Replaces sample animals and keeps any animal the farm added itself.
  Future<void> replaceSample(List<Animal> sample) async {
    _requireUser();
    final kept = [
      for (final animal in _merged(await _readAll()))
        if (!animal.id.startsWith('sample-')) animal,
    ];
    final tags = kept.map((animal) => animal.tag.toLowerCase()).toSet();
    final herd = [...kept];
    for (final animal in sample) {
      final tag = animal.tag.trim();
      if (tag.isEmpty || tags.contains(tag.toLowerCase())) {
        continue;
      }
      herd.add(animal.tag == tag ? animal : animal.copyWith(tag: tag));
      tags.add(tag.toLowerCase());
    }
    await _writeAll({farmScopeKey: herd});
  }

  @override
  Future<void> remove(String id) async {
    _requireUser();
    final herd = [..._merged(await _readAll())];
    herd.removeWhere((animal) => animal.id == id);
    await _writeAll({farmScopeKey: herd});
  }

  List<Animal> _merged(Map<String, List<Animal>> all) {
    final byId = <String, Animal>{};
    final keys = [
      for (final key in all.keys)
        if (key != farmScopeKey) key,
      if (all.containsKey(farmScopeKey)) farmScopeKey,
    ];
    for (final key in keys) {
      for (final animal in all[key] ?? const <Animal>[]) {
        byId[animal.id] = animal;
      }
    }
    return byId.values.toList();
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
