import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/app/app_backend.dart';
import 'package:shai_hills_farm/app/farm_app.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/animal_repository.dart';
import 'package:shai_hills_farm/domain/failures.dart';

void main() {
  testWidgets('create an account, register, edit, filter, and remove', (
    tester,
  ) async {
    await _pumpFarm(tester, AppBackend.local(MemoryStore()));

    expect(find.bySemanticsLabel('Katamansu Spice Farm'), findsOneWidget);
    expect(find.textContaining('On-device records'), findsOneWidget);

    await _signInPractice(tester);

    expect(find.text('0'), findsNWidgets(5));
    await tester.scrollUntilVisible(
      find.text(
        'Nothing is on the farm yet. Register the first pig, cow, goat, sheep, or bird.',
      ),
      300,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('home-page')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.text(
        'Nothing is on the farm yet. Register the first pig, cow, goat, sheep, or bird.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    expect(find.text('No animals on the register yet.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-animal')));
    await tester.pumpAndSettle();
    await _saveAnimal(tester, tag: 'SH-PIG-01', species: 'pig', sex: 'female');

    expect(find.text('SH-PIG-01'), findsOneWidget);
    expect(find.text('Pig · Female · On farm'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('count-pig')), findsOneWidget);
    expect(_countText('pig'), '1');
    expect(_countText('cattle'), '0');
    expect(find.text('1 animal on the farm'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-animal')));
    await tester.pumpAndSettle();
    await _saveAnimal(tester, tag: 'SH-GOAT-02', species: 'goat', sex: 'male');

    await tester.tap(find.byKey(const Key('filter-goat')));
    await tester.pumpAndSettle();
    expect(find.text('SH-GOAT-02'), findsOneWidget);
    expect(find.text('SH-PIG-01'), findsNothing);

    await tester.enterText(find.byKey(const Key('search-tag')), 'missing');
    await tester.pump();
    expect(find.text('Nothing on the register matches.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('search-tag')), '');
    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pumpAndSettle();

    await _openAnimal(tester, 'SH-PIG-01');
    await _scrollTo(tester, find.byKey(const Key('status-sold')), 400);
    await tester.tap(find.byKey(const Key('status-sold')));
    await tester.pump();
    await _scrollTo(tester, find.byKey(const Key('sale-weight')), 300);
    await tester.enterText(find.byKey(const Key('sale-weight')), '40');
    await tester.enterText(find.byKey(const Key('sale-price')), '800');
    await tester.enterText(find.byKey(const Key('buyer-name')), 'Kojo');
    await tester.enterText(
      find.byKey(const Key('buyer-contact')),
      '0244000001',
    );
    await _scrollTo(tester, find.byKey(const Key('save-animal')), 400);
    await tester.tap(find.byKey(const Key('save-animal')));
    await tester.pumpAndSettle();
    expect(find.text('Pig · Female · Sold'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pumpAndSettle();
    expect(_countText('pig'), '0');
    expect(_countText('goat'), '1');
    expect(find.textContaining('No animals are marked on farm'), findsNothing);

    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    await _openAnimal(tester, 'SH-PIG-01');
    await _scrollTo(tester, find.byKey(const Key('remove-animal')), 400);
    await tester.tap(find.byKey(const Key('remove-animal')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-remove')));
    await tester.pumpAndSettle();
    expect(find.text('SH-PIG-01'), findsNothing);
    expect(find.text('SH-GOAT-02'), findsOneWidget);
  });

  testWidgets('a second account sees the same herd', (tester) async {
    await _pumpFarm(tester, AppBackend.local(MemoryStore()));
    await _signInPractice(tester);
    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-animal')));
    await tester.pumpAndSettle();
    await _saveAnimal(
      tester,
      tag: 'SH-CATTLE-01',
      species: 'cattle',
      sex: 'female',
    );
    expect(find.text('SH-CATTLE-01'), findsOneWidget);

    await _signOut(tester);
    expect(find.bySemanticsLabel('Katamansu Spice Farm'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('phone-field')), '0244120008');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-field')), '000000');
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();
    expect(
      find.text('That code is not right. Check the text and try again.'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('code-field')), '123456');
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();
    expect(_countText('cattle'), '1');

    await _signOut(tester);
    await _createAccount(tester, '0244000002');
    expect(_countText('cattle'), '1');
    expect(find.textContaining('Welcome'), findsWidgets);
    expect(find.textContaining('Nothing is on the farm yet'), findsNothing);
  });

  testWidgets('duplicate tags and missing species stay on the form', (
    tester,
  ) async {
    await _pumpFarm(tester, AppBackend.local(MemoryStore()));
    await _signInPractice(tester);
    await tester.tap(find.byKey(const Key('nav-register')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-animal')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.byKey(const Key('save-animal')), 400);
    await tester.tap(find.byKey(const Key('save-animal')));
    await tester.pump();
    expect(find.text('Choose a species.'), findsOneWidget);

    await _saveAnimal(tester, tag: 'SH-PIG-01', species: 'pig', sex: 'female');
    await tester.tap(find.byKey(const Key('add-animal')));
    await tester.pumpAndSettle();
    await _fillAnimal(tester, tag: 'sh-pig-01', species: 'pig', sex: 'male');
    await _scrollTo(tester, find.byKey(const Key('save-animal')), 400);
    await tester.tap(find.byKey(const Key('save-animal')));
    await tester.pump();
    expect(
      find.text('Tag sh-pig-01 is already on the register.'),
      findsOneWidget,
    );
    expect(find.text('Edit animal'), findsNothing);
  });

  testWidgets('shows a loading state, then the empty herd', (tester) async {
    final store = MemoryStore();
    final local = AppBackend.local(store);
    final gate = Completer<void>();
    final backend = AppBackend(
      auth: local.auth,
      animals: _GatedAnimals(local.animals, gate),
      book: local.book,
      ledger: local.ledger,
      feed: local.feed,
      tasks: local.tasks,
      sync: local.sync,
      localOnly: true,
    );
    await _pumpFarm(tester, backend);
    await _signInPractice(tester, settle: false);
    expect(find.text('Loading the herd…'), findsOneWidget);

    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Loading the herd…'), findsNothing);
    expect(_countText('poultry'), '0');
  });

  testWidgets('shows an error and retries', (tester) async {
    final store = MemoryStore();
    final local = AppBackend.local(store);
    var failures = 0;
    final backend = AppBackend(
      auth: local.auth,
      animals: _FlakyAnimals(local.animals, () => failures++ < 1),
      book: local.book,
      ledger: local.ledger,
      feed: local.feed,
      tasks: local.tasks,
      sync: local.sync,
      localOnly: true,
    );
    await _pumpFarm(tester, backend);
    await _signInPractice(tester);
    expect(find.text('The herd could not be loaded'), findsOneWidget);
    expect(find.text('The barn book is locked.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('The herd could not be loaded'), findsNothing);
    expect(_countText('pig'), '0');
  });

  testWidgets('rejects a short phone number before sending a code', (
    tester,
  ) async {
    await _pumpFarm(tester, AppBackend.local(MemoryStore()));
    await tester.enterText(find.byKey(const Key('phone-field')), '123');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    expect(
      find.text('Enter the phone number you use, like 024 412 0008.'),
      findsOneWidget,
    );
    expect(find.text('Home'), findsNothing);
  });
}

String _countText(String species) {
  final finder = find.byKey(Key('count-$species'));
  final widget = finder.evaluate().single.widget;
  return (widget as Text).data!;
}

Future<void> _pumpFarm(WidgetTester tester, AppBackend backend) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(FarmApp(backend: backend));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _signInPractice(WidgetTester tester, {bool settle = true}) async {
  await tester.enterText(find.byKey(const Key('phone-field')), '0244120008');
  await tester.tap(find.byKey(const Key('send-code')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('code-field')), '123456');
  await tester.tap(find.byKey(const Key('submit-auth')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> _createAccount(WidgetTester tester, String phone) async {
  await tester.tap(find.byKey(const Key('switch-auth-mode')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('name-field')), 'Ama');
  await tester.enterText(find.byKey(const Key('phone-field')), phone);
  await tester.tap(find.byKey(const Key('send-code')));
  await tester.pumpAndSettle();
  final notice = tester.widget<Text>(find.textContaining('Your code is '));
  final code = RegExp(r'Your code is (\d{6})')
      .firstMatch(notice.data!)!
      .group(1)!;
  await tester.enterText(find.byKey(const Key('code-field')), code);
  await tester.tap(find.byKey(const Key('submit-auth')));
  await tester.pumpAndSettle();
}

Future<void> _fillAnimal(
  WidgetTester tester, {
  required String tag,
  required String species,
  required String sex,
}) async {
  await tester.enterText(find.byKey(const Key('tag-field')), tag);
  await tester.tap(find.byKey(Key('species-$species')));
  await tester.pump();
  await tester.tap(find.byKey(Key('sex-$sex')));
  await tester.pump();
  final breed = switch (species) {
    'goat' => 'West African Dwarf',
    'cattle' => 'Sokoto Gudali',
    'sheep' => 'West African Dwarf',
    'poultry' => 'Local',
    _ => 'Large White',
  };
  await _scrollTo(tester, find.byKey(Key('breed-$breed')), 200);
  await tester.tap(find.byKey(Key('breed-$breed')));
  await tester.pump();
  await _scrollTo(tester, find.byKey(const Key('origin-purchased')), 200);
  await tester.tap(find.byKey(const Key('origin-purchased')));
  await tester.pump();
  await _scrollTo(tester, find.byKey(const Key('source-farm')), 200);
  await tester.enterText(find.byKey(const Key('source-farm')), 'Market');
  await tester.enterText(find.byKey(const Key('supplier-name')), 'Market');
  await tester.enterText(find.byKey(const Key('purchase-weight')), '12');
  await tester.enterText(find.byKey(const Key('purchase-price')), '200');
  await tester.enterText(find.byKey(const Key('transport-cost')), '0');
}

Future<void> _saveAnimal(
  WidgetTester tester, {
  required String tag,
  required String species,
  required String sex,
}) async {
  await _fillAnimal(tester, tag: tag, species: species, sex: sex);
  await _scrollTo(tester, find.byKey(const Key('save-animal')), 400);
  await tester.tap(find.byKey(const Key('save-animal')));
  await tester.pumpAndSettle();
}

Future<void> _openAnimal(WidgetTester tester, String tag) async {
  final tile = find.byKey(Key('animal-$tag'));
  final scrollable = find
      .descendant(
        of: find.byKey(const Key('registry-page')),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(tile, 400, scrollable: scrollable);
  await tester.pumpAndSettle();
  final bottom = tester.getRect(tile).bottom;
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  const clearance = 120.0;
  if (bottom > height - clearance) {
    await tester.drag(scrollable, Offset(0, height - clearance - bottom));
    await tester.pumpAndSettle();
  }
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, [
  double delta = 400,
]) {
  return tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('animal-form')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

Future<void> _signOut(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('account-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sign-out-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-sign-out')));
  await tester.pumpAndSettle();
}

class _GatedAnimals implements AnimalRepository {
  _GatedAnimals(this.inner, this.gate);

  final AnimalRepository inner;
  final Completer<void> gate;

  @override
  Future<List<Animal>> list() async {
    await gate.future;
    return inner.list();
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<Animal> save(Animal animal) => inner.save(animal);
}

class _FlakyAnimals implements AnimalRepository {
  _FlakyAnimals(this.inner, this.shouldFail);

  final AnimalRepository inner;
  final bool Function() shouldFail;

  @override
  Future<List<Animal>> list() async {
    if (shouldFail()) {
      throw const RegisterFailure('The barn book is locked.');
    }
    return inner.list();
  }

  @override
  Future<void> remove(String id) => inner.remove(id);

  @override
  Future<Animal> save(Animal animal) => inner.save(animal);
}
