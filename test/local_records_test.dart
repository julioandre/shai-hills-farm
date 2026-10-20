import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/config/app_config.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_auth_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/data/supabase_animal_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('local accounts are scoped and passwords are checked', () async {
    final auth = LocalAuthRepository(MemoryStore());
    const email = 'keeper@shaihills.farm';
    const password = 'pasture-1';

    final created = await auth.signUp(email: email, password: password);
    expect(created.email, email);
    await auth.signOut();
    expect(auth.session, isNull);

    expect(
      () => auth.signIn(email: email, password: 'wrong-pass'),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'message',
          'That email and password do not match an account on this device.',
        ),
      ),
    );

    final signedIn = await auth.signIn(
      email: 'Keeper@ShaiHills.farm',
      password: password,
    );
    expect(signedIn.userId, created.userId);

    expect(
      () => auth.signUp(email: email, password: password),
      throwsA(isA<AuthFailure>()),
    );
  });

  test('each account has its own animals', () async {
    final store = MemoryStore();
    final auth = LocalAuthRepository(store);
    final animals = LocalAnimalRepository(
      store: store,
      userId: () => auth.session?.userId,
    );

    await auth.signUp(email: 'one@shaihills.farm', password: 'pasture-1');
    await animals.save(_pig('SH-1'));
    final firstUser = auth.session!.userId;
    await auth.signOut();

    await auth.signUp(email: 'two@shaihills.farm', password: 'pasture-1');
    expect(await animals.list(), isEmpty);
    await animals.save(_goat('SH-9'));
    expect((await animals.list()).single.tag, 'SH-9');

    await auth.signOut();
    await auth.signIn(email: 'one@shaihills.farm', password: 'pasture-1');
    expect(auth.session!.userId, firstUser);
    final herd = await animals.list();
    expect(herd.single.tag, 'SH-1');

    expect(() => animals.save(_pig('sh-1')), throwsA(isA<RegisterFailure>()));
  });

  test('a restored session reopens the same account', () async {
    final store = MemoryStore();
    final first = LocalAuthRepository(store);
    final created = await first.signUp(
      email: 'keeper@shaihills.farm',
      password: 'pasture-1',
    );

    final second = LocalAuthRepository(store);
    final restored = await second.restore();
    expect(restored?.userId, created.userId);
    expect(restored?.email, 'keeper@shaihills.farm');
  });

  test('partial Supabase config is called out', () {
    const missingKey = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: '',
    );
    expect(missingKey.hasSupabase, isFalse);
    expect(missingKey.partialSupabaseNotice, contains('SUPABASE_ANON_KEY'));

    const ready = AppConfig(
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'public-anon',
    );
    expect(ready.hasSupabase, isTrue);
    expect(ready.partialSupabaseNotice, isNull);
  });

  test('a missing animals table gets a setup message', () {
    const error = PostgrestException(
      message: "Could not find the table 'public.animals' in the schema cache",
      code: 'PGRST205',
    );
    expect(registerErrorMessage(error), contains('20261020140000_animals.sql'));
    expect(
      registerErrorMessage(
        const PostgrestException(message: 'duplicate key', code: '23505'),
      ),
      'That tag is already on the register.',
    );
  });
}

Animal _pig(String tag) {
  return Animal(
    id: tag,
    tag: tag,
    species: Species.pig,
    sex: Sex.female,
    status: AnimalStatus.onFarm,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

Animal _goat(String tag) {
  return Animal(
    id: tag,
    tag: tag,
    species: Species.goat,
    sex: Sex.male,
    status: AnimalStatus.onFarm,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}
