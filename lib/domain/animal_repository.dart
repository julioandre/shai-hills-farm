import 'package:shai_hills_farm/domain/animal.dart';

/// Reads and writes the animal register.
///
/// Sprint 1 has two implementations: Supabase, and an on-device store used
/// when no Supabase project is configured. Offline sync (sprint 6) can add
/// another implementation behind this same type. Callers should not talk to
/// either store directly.
abstract interface class AnimalRepository {
  Future<List<Animal>> list();

  Future<Animal> save(Animal animal);

  Future<void> remove(String id);
}
