import 'package:shai_hills_farm/domain/farm_entry.dart';

/// Reads and writes the farm book.
///
/// On-device storage is used when no Supabase project is configured.
/// Callers should not talk to either store directly.
abstract interface class BookRepository {
  Future<List<FarmEntry>> list();

  Future<FarmEntry> save(FarmEntry entry);

  Future<void> remove(String id);
}
