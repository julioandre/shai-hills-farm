import 'package:shai_hills_farm/data/key_value_store.dart';

/// In-memory store for tests and for wiring the app without plugins.
class MemoryStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      values.remove(key);
      return;
    }
    values[key] = value;
  }
}
