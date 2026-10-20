import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/data/supabase_animal_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/validation.dart';

class HerdController extends ChangeNotifier {
  HerdController(this._repository);

  final AnimalRepository _repository;

  List<Animal> animals = [];
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
      final rows = sortAnimals(await _repository.list());
      if (epoch != _epoch || ticket != _loadTicket) {
        return;
      }
      animals = rows;
      error = null;
      refreshError = null;
    } catch (caught) {
      if (epoch != _epoch || ticket != _loadTicket) {
        return;
      }
      final message = registerErrorMessage(caught);
      if (animals.isEmpty) {
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

  Future<String?> save(Animal animal) async {
    final message = validateAnimal(
      tag: animal.tag,
      species: animal.species,
      sex: animal.sex,
      status: animal.status,
      existing: animals,
      exceptId: animal.id,
    );
    if (message != null) {
      return message;
    }
    _epoch++;
    try {
      final saved = await _repository.save(animal);
      animals = sortAnimals([
        ...animals.where((item) => item.id != saved.id),
        saved,
      ]);
      error = null;
      refreshError = null;
      notifyListeners();
      return null;
    } catch (caught) {
      return registerErrorMessage(caught);
    }
  }

  Future<String?> remove(String id) async {
    _epoch++;
    try {
      await _repository.remove(id);
      animals = animals.where((animal) => animal.id != id).toList();
      error = null;
      refreshError = null;
      notifyListeners();
      return null;
    } catch (caught) {
      return registerErrorMessage(caught);
    }
  }

  void clear() {
    _epoch++;
    _loadTicket++;
    animals = [];
    loading = false;
    error = null;
    refreshError = null;
    notifyListeners();
  }
}
