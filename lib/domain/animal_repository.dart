import 'package:shai_hills_farm/domain/animal.dart';

/// Reads and writes the animal register.
///
/// On-device storage is used when no Supabase project is configured.
/// Callers should not talk to either store directly.
abstract interface class AnimalRepository {
  Future<List<Animal>> list();

  Future<Animal> save(Animal animal);

  Future<void> remove(String id);
}
