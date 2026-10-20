/// Small string store used by the on-device account and register.
abstract interface class KeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String? value);
}
