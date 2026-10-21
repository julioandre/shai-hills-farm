import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/data/local_auth_repository.dart';
import 'package:shai_hills_farm/data/local_book_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/data/supabase_book_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/month_totals.dart';
import 'package:shai_hills_farm/domain/validation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('every account shares one farm book', () async {
    final store = MemoryStore();
    final auth = LocalAuthRepository(store);
    final book = LocalBookRepository(
      store: store,
      userId: () => auth.session?.userId,
    );

    await _register(auth, '0244000001');
    await book.save(_feed('bran'));
    await auth.signOut();

    await _register(auth, '0244000002');
    expect((await book.list()).single.note, 'Maize bran for the pigs');

    await auth.signOut();
    final again = await auth.sendCode(phone: '0244000001', creating: false);
    await auth.verifyCode(phone: '0244000001', code: again.previewCode!);
    expect((await book.list()).single.note, 'Maize bran for the pigs');

    await book.remove('bran');
    expect(await book.list(), isEmpty);
  });

  test('this month counts milk, sales, and deaths only', () {
    final october = DateTime(2026, 10, 20);
    final totals = MonthTotals.forMonth([
      _entry(
        id: 'milk-now',
        kind: BookKind.milk,
        day: DateTime(2026, 10, 2),
        amount: 12.5,
      ),
      _entry(
        id: 'milk-old',
        kind: BookKind.milk,
        day: DateTime(2026, 9, 30),
        amount: 4,
      ),
      _entry(
        id: 'sale',
        kind: BookKind.sale,
        day: DateTime(2026, 10, 5),
        amount: 450,
        tag: 'SH-GOAT-02',
      ),
      _entry(
        id: 'death',
        kind: BookKind.death,
        day: DateTime(2026, 10, 6),
        tag: 'SH-PIG-03',
      ),
      _entry(
        id: 'death-old',
        kind: BookKind.death,
        day: DateTime(2026, 8, 1),
        tag: 'SH-PIG-01',
      ),
      _entry(id: 'health', kind: BookKind.health, day: DateTime(2026, 10, 7)),
    ], october);

    expect(totals.notes, 4);
    expect(totals.milkLitres, 12.5);
    expect(totals.salesCedis, 450);
    expect(totals.deaths, 1);
    expect(formatCedis(450), 'GH₵ 450');
    expect(formatLitres(12.5), '12.5 L');
    expect(statusAfter(BookKind.sale), AnimalStatus.sold);
    expect(statusAfter(BookKind.death), AnimalStatus.dead);
    expect(statusAfter(BookKind.health), isNull);
  });

  test('a note needs a kind, an animal for a sale, and litres for milk', () {
    final today = DateTime(2026, 10, 20);
    final pig = Animal(
      id: 'pig',
      tag: 'SH-PIG-01',
      species: Species.pig,
      sex: Sex.female,
      status: AnimalStatus.onFarm,
      updatedAt: today,
    );

    expect(
      validateEntry(
        kind: null,
        happenedOn: today,
        note: 'Dewormed',
        amountText: '',
        today: today,
      ),
      'Choose what happened.',
    );
    expect(
      validateEntry(
        kind: BookKind.health,
        happenedOn: today,
        note: '   ',
        amountText: '',
        today: today,
      ),
      'Write a short note.',
    );
    expect(
      validateEntry(
        kind: BookKind.sale,
        happenedOn: today,
        note: '',
        amountText: '450',
        today: today,
      ),
      'Choose the animal.',
    );
    expect(
      validateEntry(
        kind: BookKind.milk,
        happenedOn: today,
        note: '',
        amountText: '',
        animal: pig,
        today: today,
      ),
      'Milk is for cattle or goats.',
    );
    expect(
      validateEntry(
        kind: BookKind.feed,
        happenedOn: today,
        note: 'Maize bran for the pigs',
        amountText: '',
        today: today,
      ),
      isNull,
    );
    expect(parseAmount('12,5'), 12.5);
  });

  test('a missing farm book table gets a setup message', () {
    const error = PostgrestException(
      message:
          "Could not find the table 'public.farm_entries' in the schema cache",
      code: 'PGRST205',
    );
    expect(bookErrorMessage(error), contains('20261020180000_farm_book.sql'));
  });
}

FarmEntry _feed(String id) {
  return FarmEntry(
    id: id,
    kind: BookKind.feed,
    happenedOn: DateTime(2026, 10, 20),
    note: 'Maize bran for the pigs',
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

FarmEntry _entry({
  required String id,
  required BookKind kind,
  required DateTime day,
  double? amount,
  String? tag,
}) {
  return FarmEntry(
    id: id,
    kind: kind,
    happenedOn: day,
    animalId: tag,
    animalTag: tag,
    note: kind.label,
    amount: amount,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

Future<void> _register(LocalAuthRepository auth, String phone) async {
  final sent = await auth.sendCode(phone: phone, creating: true);
  await auth.verifyCode(phone: phone, code: sent.previewCode!);
}
