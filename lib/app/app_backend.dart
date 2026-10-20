import 'package:shared_preferences/shared_preferences.dart';
import 'package:shai_hills_farm/config/app_config.dart';
import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_auth_repository.dart';
import 'package:shai_hills_farm/data/preferences_store.dart';
import 'package:shai_hills_farm/data/supabase_animal_repository.dart';
import 'package:shai_hills_farm/data/supabase_auth_repository.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth and the animal register, either on this device or in Supabase.
class AppBackend {
  const AppBackend({
    required this.auth,
    required this.animals,
    required this.localOnly,
    this.startupNotice,
  });

  final AuthRepository auth;
  final AnimalRepository animals;
  final bool localOnly;
  final String? startupNotice;

  factory AppBackend.local(KeyValueStore store, {String? startupNotice}) {
    final auth = LocalAuthRepository(store);
    return AppBackend(
      auth: auth,
      animals: LocalAnimalRepository(
        store: store,
        userId: () => auth.session?.userId,
      ),
      localOnly: true,
      startupNotice: startupNotice,
    );
  }

  static Future<AppBackend> start(AppConfig config) async {
    if (!config.hasSupabase) {
      return _local(config.partialSupabaseNotice);
    }
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabaseAnonKey,
      );
    } catch (_) {
      return _local(
        'Supabase did not start, so this session is using on-device records.',
      );
    }
    final client = Supabase.instance.client;
    final auth = SupabaseAuthRepository(client);
    return AppBackend(
      auth: auth,
      animals: SupabaseAnimalRepository(
        client,
        userId: () => auth.session?.userId,
      ),
      localOnly: false,
    );
  }

  static Future<AppBackend> _local(String? notice) async {
    final preferences = await SharedPreferences.getInstance();
    return AppBackend.local(
      PreferencesStore(preferences),
      startupNotice: notice,
    );
  }
}
