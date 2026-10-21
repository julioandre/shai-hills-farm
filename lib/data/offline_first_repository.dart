import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/book_repository.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';

const _offlineWait = Duration(seconds: 6);

/// Tries the server, and uses the phone copy when there is no signal.
class OfflineFirstAnimalRepository implements AnimalRepository {
  OfflineFirstAnimalRepository({required this.local, required this.remote});

  final AnimalRepository local;
  final AnimalRepository remote;

  @override
  Future<List<Animal>> list() async {
    try {
      final rows = await remote.list().timeout(_offlineWait);
      for (final animal in rows) {
        try {
          await local.save(animal);
        } catch (_) {
          // A tag clash in the phone copy should not hide the server herd.
        }
      }
      return rows;
    } catch (_) {
      return local.list();
    }
  }

  @override
  Future<Animal> save(Animal animal) async {
    final stored = await local.save(animal);
    try {
      return await remote.save(stored).timeout(_offlineWait);
    } catch (_) {
      return stored;
    }
  }

  @override
  Future<void> remove(String id) async {
    await local.remove(id);
    try {
      await remote.remove(id).timeout(_offlineWait);
    } catch (_) {}
  }
}

class OfflineFirstBookRepository implements BookRepository {
  OfflineFirstBookRepository({required this.local, required this.remote});

  final BookRepository local;
  final BookRepository remote;

  @override
  Future<List<FarmEntry>> list() async {
    try {
      final rows = await remote.list().timeout(_offlineWait);
      for (final entry in rows) {
        try {
          await local.save(entry);
        } catch (_) {}
      }
      return rows;
    } catch (_) {
      return local.list();
    }
  }

  @override
  Future<FarmEntry> save(FarmEntry entry) async {
    final stored = await local.save(entry);
    try {
      return await remote.save(stored).timeout(_offlineWait);
    } catch (_) {
      return stored;
    }
  }

  @override
  Future<void> remove(String id) async {
    await local.remove(id);
    try {
      await remote.remove(id).timeout(_offlineWait);
    } catch (_) {}
  }
}
