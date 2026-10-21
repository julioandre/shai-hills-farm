import 'package:shared_preferences/shared_preferences.dart';
import 'package:shai_hills_farm/data/key_value_store.dart';


class PreferencesStore implements KeyValueStore {
  PreferencesStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<String?> read(String key) async => _preferences.getString(key);

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      await _preferences.remove(key);
      return;
    }
    await _preferences.setString(key, value);
  }
}
