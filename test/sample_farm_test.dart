import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_feed_repository.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/data/sample_farm.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/herd_counts.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

void main() {
  test('an empty phone gets one sample farm and keeps it', () async {
    final store = MemoryStore();
    await seedSampleFarm(store);
    await seedSampleFarm(store);

    final animals = await LocalAnimalRepository(
      store: store,
      userId: () => 'reader',
    ).list();
    final counts = HerdCounts.fromAnimals(animals);
    expect(counts.pigs, 1000);
    expect(counts.cattle, 100);
    expect(counts.goats, 20);
    expect(counts.poultry, 0);
    expect(animals, hasLength(1000 + 100 + 20 + 3));
    final pigs = animals.where(
      (animal) =>
          animal.species == Species.pig && animal.status == AnimalStatus.onFarm,
    );
    expect(
      pigs.where((animal) => pigClassOf(animal) == PigClass.sow),
      hasLength(380),
    );
    expect(
      pigs.where((animal) => pigClassOf(animal) == PigClass.boar),
      hasLength(20),
    );
    expect(
      pigs.where((animal) => pigClassOf(animal) == PigClass.grower),
      hasLength(600),
    );

    final today = DateTime.now();
    final ledger = await LocalLedgerRepository(store).read();
    final feed = ledger.expenses.where(
      (row) => row.category == ExpenseCategory.feed,
    );
    expect(feed.length, greaterThanOrEqualTo(6));
    expect(feed.map((row) => row.quantityKg), contains(200));
    expect(ledger.expenses.length, greaterThanOrEqualTo(1000));
    expect(ledger.sales.length, greaterThanOrEqualTo(1000));
    expect(ledger.deaths.length, greaterThan(1));
    expect(
      ledger.health.where((row) => row.animalTag.startsWith('GOAT')),
      isNotEmpty,
    );
    final oldest = DateTime(today.year, today.month - 5, 1);
    expect(
      ledger.expenses.every(
        (row) => !DateTime(
          row.happenedOn.year,
          row.happenedOn.month,
        ).isBefore(oldest),
      ),
      isTrue,
    );
    expect(
      ledger.sales.every(
        (row) => !DateTime(
          row.happenedOn.year,
          row.happenedOn.month,
        ).isBefore(oldest),
      ),
      isTrue,
    );
    expect(ledger.births.length, greaterThan(2));

    final kpis = FarmKpis.evaluate(
      animals: animals,
      ledger: ledger,
      today: today,
    );
    expect(kpis.birthsToday, 1);
    expect(kpis.feedKgToday, 132);
    expect(kpis.revenue, greaterThan(0));
    expect(kpis.attention, isNotEmpty);
    expect(kpis.sowScores.first.damTag, 'SOW-1');
  });

  test('an existing sample farm gains the older expenses', () async {
    final store = MemoryStore();
    await seedSampleFarm(store);
    final repository = LocalLedgerRepository(store);
    final current = await repository.read();
    await repository.replace(
      current.copyWith(
        expenses: [
          current.expenses.singleWhere(
            (row) => row.id == 'sample-expense-feed',
          ),
        ],
      ),
    );

    await seedSampleFarm(store);

    final ledger = await repository.read();
    expect(
      ledger.expenses
          .where((row) => row.category == ExpenseCategory.feed)
          .length,
      greaterThanOrEqualTo(6),
    );
    expect(ledger.expenses.length, greaterThanOrEqualTo(1000));
    expect(ledger.sales.length, greaterThanOrEqualTo(1000));
    final animals = await LocalAnimalRepository(
      store: store,
      userId: () => 'reader',
    ).list();
    expect(HerdCounts.fromAnimals(animals).pigs, 1000);
  });

  test('clearing the sample farm keeps an animal the farm added', () async {
    final store = MemoryStore();
    await seedSampleFarm(store);
    final animals = LocalAnimalRepository(store: store, userId: () => 'reader');
    await animals.save(
      Animal(
        id: 'own-sow',
        tag: 'SOW-KEEP',
        species: Species.pig,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        updatedAt: DateTime.utc(2026, 10, 21),
      ),
    );

    await clearSampleFarm(store);

    final left = await animals.list();
    expect(left.map((animal) => animal.tag), ['SOW-KEEP']);
    final ledger = await LocalLedgerRepository(store).read();
    expect(ledger.sales, isEmpty);
    expect(ledger.expenses, isEmpty);
    expect(ledger.births, isEmpty);
    final feed = await LocalFeedRepository(store).read();
    expect(feed.ingredients, isEmpty);
    expect(feed.formulas, isEmpty);
  });
}
