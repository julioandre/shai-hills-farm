import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/config/app_config.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_auth_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/data/supabase_animal_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/failures.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'the practice account accepts its code and rejects a wrong one',
    () async {
      final auth = LocalAuthRepository(MemoryStore());
      final sent = await auth.sendCode(phone: '024 412 0008', creating: false);
      expect(sent.previewCode, demoOtp);
      expect(sent.message, contains('024 412 0008'));

      expect(
        () => auth.verifyCode(phone: demoPhone, code: '000000'),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            'That code is not right. Check the text and try again.',
          ),
        ),
      );

      final signedIn = await auth.verifyCode(
        phone: '+233244120008',
        code: demoOtp,
      );
      expect(signedIn.phone, demoPhone);
      expect(signedIn.userId, demoUserId);
      expect(signedIn.role, FarmRole.admin);
      await auth.signOut();
      expect(auth.session, isNull);

      expect(
        () => auth.sendCode(phone: demoPhone, creating: true),
        throwsA(isA<AuthFailure>()),
      );
    },
  );

  test('the practice worker can sign in and cannot see money', () async {
    final auth = LocalAuthRepository(MemoryStore());
    final sent = await auth.sendCode(phone: workerPhone, creating: false);
    expect(sent.previewCode, demoOtp);

    final signedIn = await auth.verifyCode(phone: workerPhone, code: demoOtp);
    expect(signedIn.userId, workerUserId);
    expect(signedIn.role, FarmRole.worker);
    expect(signedIn.access.viewFinancials, isFalse);
    expect(signedIn.access.allowed, isNot(contains('See sales and expenses')));
    expect(signedIn.access.allowed, contains('Give feed and mix a batch'));
    expect(signedIn.herds, {Species.pig});
    expect(signedIn.access.allows(Species.pig), isTrue);
    expect(signedIn.access.allows(Species.cattle), isFalse);
    expect(signedIn.access.allows(Species.poultry), isFalse);

    final denied = LocalAuthRepository(MemoryStore());
    await denied.sendCode(phone: workerPhone, creating: false);
    await denied.verifyCode(phone: workerPhone, code: demoOtp);
    expect(
      () =>
          denied.assignHerds(userId: signedIn.userId, herds: {Species.cattle}),
      throwsA(isA<AuthFailure>()),
    );
  });

  test(
    'a worker sees the herds an admin assigns, including more than one',
    () async {
      final auth = LocalAuthRepository(MemoryStore());
      await auth.sendCode(phone: demoPhone, creating: false);
      await auth.verifyCode(phone: demoPhone, code: demoOtp);
      final sent = await auth.sendCode(phone: '0244000099', creating: true);
      final worker = await auth.verifyCode(
        phone: '0244000099',
        code: sent.previewCode!,
      );
      expect(worker.access.seesEveryHerd, isTrue);
      await auth.signOut();

      await auth.sendCode(phone: demoPhone, creating: false);
      await auth.verifyCode(phone: demoPhone, code: demoOtp);
      await auth.assignHerds(
        userId: worker.userId,
        herds: {Species.cattle, Species.poultry},
      );
      await auth.signOut();

      final again = await auth.sendCode(phone: '0244000099', creating: false);
      final limited = await auth.verifyCode(
        phone: '0244000099',
        code: again.previewCode!,
      );
      expect(limited.access.allows(Species.cattle), isTrue);
      expect(limited.access.allows(Species.poultry), isTrue);
      expect(limited.access.allows(Species.pig), isFalse);
      expect(
        FarmAccess(
          FarmRole.worker,
          herds: {Species.goat},
        ).allows(Species.sheep),
        isTrue,
      );
    },
  );

  test('every account shares one farm register', () async {
    final store = MemoryStore();
    final auth = LocalAuthRepository(store);
    final animals = LocalAnimalRepository(
      store: store,
      userId: () => auth.session?.userId,
    );

    await _register(auth, '0244000001');
    await animals.save(_pig('SH-1'));
    final firstUser = auth.session!.userId;
    expect(auth.session!.role, FarmRole.worker);
    await auth.signOut();

    await _register(auth, '0244000002');
    expect((await animals.list()).single.tag, 'SH-1');
    await animals.save(_goat('SH-9'));

    await auth.signOut();
    final again = await auth.sendCode(phone: '0244000001', creating: false);
    await auth.verifyCode(phone: '0244000001', code: again.previewCode!);
    expect(auth.session!.userId, firstUser);
    final tags = (await animals.list()).map((animal) => animal.tag).toSet();
    expect(tags, {'SH-1', 'SH-9'});

    expect(() => animals.save(_pig('sh-1')), throwsA(isA<RegisterFailure>()));
  });

  test('an admin assigns roles and a worker cannot', () async {
    final auth = LocalAuthRepository(MemoryStore());
    final sent = await auth.sendCode(phone: demoPhone, creating: false);
    final admin = await auth.verifyCode(
      phone: demoPhone,
      code: sent.previewCode!,
    );
    expect(admin.role, FarmRole.admin);
    await auth.signOut();

    final worker = await _register(auth, '0244000003');
    expect(worker.role, FarmRole.worker);
    expect(
      () => auth.assignRole(userId: admin.userId, role: FarmRole.manager),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'message',
          'Only an admin can change roles.',
        ),
      ),
    );

    await auth.signOut();
    final again = await auth.sendCode(phone: demoPhone, creating: false);
    await auth.verifyCode(phone: demoPhone, code: again.previewCode!);
    await auth.assignRole(userId: worker.userId, role: FarmRole.manager);
    final people = await auth.listPeople();
    expect(
      people.firstWhere((person) => person.userId == worker.userId).role,
      FarmRole.manager,
    );

    for (var index = 1; index <= 9; index++) {
      await auth.signOut();
      await _register(auth, '020000000$index');
    }
    expect((await auth.listPeople()).length, greaterThan(8));
  });

  test('a restored session reopens the same account', () async {
    final store = MemoryStore();
    final first = LocalAuthRepository(store);
    final created = await _register(first, '0244000001');

    final second = LocalAuthRepository(store);
    final restored = await second.restore();
    expect(restored?.userId, created.userId);
    expect(restored?.phone, normalizePhone('0244000001'));
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

Future<FarmSession> _register(LocalAuthRepository auth, String phone) async {
  final sent = await auth.sendCode(phone: phone, creating: true);
  return auth.verifyCode(phone: phone, code: sent.previewCode!);
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
