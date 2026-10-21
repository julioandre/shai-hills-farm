import 'package:shared_preferences/shared_preferences.dart';
import 'package:shai_hills_farm/config/app_config.dart';
import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_auth_repository.dart';
import 'package:shai_hills_farm/data/local_book_repository.dart';
import 'package:shai_hills_farm/data/local_feed_repository.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/data/local_task_repository.dart';
import 'package:shai_hills_farm/data/offline_first_repository.dart';
import 'package:shai_hills_farm/data/preferences_store.dart';
import 'package:shai_hills_farm/data/sample_farm.dart';
import 'package:shai_hills_farm/data/supabase_animal_repository.dart';
import 'package:shai_hills_farm/data/supabase_auth_repository.dart';
import 'package:shai_hills_farm/data/supabase_book_repository.dart';
import 'package:shai_hills_farm/data/supabase_sync_target.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/auth_repository.dart';
import 'package:shai_hills_farm/domain/book_repository.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth, the animal register, and the farm book.
///
/// Records stay on this device until a Supabase project is connected.
class AppBackend {
  const AppBackend({
    required this.auth,
    required this.animals,
    required this.book,
    required this.ledger,
    required this.feed,
    required this.tasks,
    required this.sync,
    required this.localOnly,
    this.startupNotice,
  });

  final AuthRepository auth;
  final AnimalRepository animals;
  final BookRepository book;
  final LocalLedgerRepository ledger;
  final LocalFeedRepository feed;
  final LocalTaskRepository tasks;
  final SyncTarget sync;
  final bool localOnly;
  final String? startupNotice;

  factory AppBackend.local(KeyValueStore store, {String? startupNotice}) {
    final auth = LocalAuthRepository(store);
    String? currentUser() => auth.session?.userId;
    return AppBackend(
      auth: auth,
      animals: LocalAnimalRepository(store: store, userId: currentUser),
      book: LocalBookRepository(store: store, userId: currentUser),
      ledger: LocalLedgerRepository(store),
      feed: LocalFeedRepository(store),
      tasks: LocalTaskRepository(store),
      sync: LocalSyncTarget(),
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
      ).timeout(const Duration(seconds: 8));
    } catch (_) {
      return _local(
        'Supabase did not start, so this session is using on-device records.',
      );
    }
    final client = Supabase.instance.client;
    final auth = SupabaseAuthRepository(client);
    String? currentUser() => auth.session?.userId;
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesStore(preferences);
    return AppBackend(
      auth: auth,
      animals: OfflineFirstAnimalRepository(
        local: LocalAnimalRepository(store: store, userId: currentUser),
        remote: SupabaseAnimalRepository(client, userId: currentUser),
      ),
      book: OfflineFirstBookRepository(
        local: LocalBookRepository(store: store, userId: currentUser),
        remote: SupabaseBookRepository(client, userId: currentUser),
      ),
      ledger: LocalLedgerRepository(store),
      feed: LocalFeedRepository(store),
      tasks: LocalTaskRepository(store),
      sync: SupabaseSyncTarget(client),
      localOnly: false,
    );
  }

  static Future<AppBackend> _local(String? notice) async {
    final preferences = await SharedPreferences.getInstance();
    final store = PreferencesStore(preferences);
    await seedSampleFarm(store);
    return AppBackend.local(store, startupNotice: notice);
  }
}
