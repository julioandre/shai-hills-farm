import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_book_repository.dart';
import 'package:shai_hills_farm/data/local_feed_repository.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

/// Fills an empty on-device farm so Home, Money, Animals, and Book have rows.
///
/// A phone that already has the sample herd picks up the latest sample rows.
/// A herd with no sample tags is left alone.
List<T> _keepOwn<T>(
  List<T> current,
  List<T> sample,
  String Function(T row) id,
) {
  return [
    for (final row in current)
      if (!id(row).startsWith('sample-')) row,
    ...sample,
  ];
}

Future<void> seedSampleFarm(KeyValueStore store) async {
  const reader = 'sample';
  final animals = LocalAnimalRepository(store: store, userId: () => reader);
  final existing = await animals.list();
  final sampleFarm =
      existing.isEmpty ||
      existing.any((animal) => animal.id.startsWith('sample-'));
  if (!sampleFarm) {
    return;
  }

  final now = DateTime.now();
  await animals.replaceSample(_animals(now.toUtc()));

  final ledger = LocalLedgerRepository(store);
  final current = await ledger.read();
  final sampleLedger =
      current.births.isEmpty &&
          current.expenses.isEmpty &&
          current.sales.isEmpty ||
      current.births.any((row) => row.id.startsWith('sample-')) ||
      current.expenses.any((row) => row.id.startsWith('sample-')) ||
      current.sales.any((row) => row.id.startsWith('sample-'));
  if (sampleLedger) {
    final fresh = _ledger(now);
    final today = DateTime(now.year, now.month, now.day);
    final weights = [...fresh.weights, ..._gainWeights(today, now.toUtc())];
    await ledger.replace(
      current.copyWith(
        births: _keepOwn(current.births, fresh.births, (row) => row.id),
        deaths: _keepOwn(current.deaths, fresh.deaths, (row) => row.id),
        feedUses: _keepOwn(current.feedUses, fresh.feedUses, (row) => row.id),
        purchases: _keepOwn(
          current.purchases,
          fresh.purchases,
          (row) => row.id,
        ),
        breeding: _keepOwn(current.breeding, fresh.breeding, (row) => row.id),
        weights: _keepOwn(current.weights, weights, (row) => row.id),
        health: _keepOwn(current.health, fresh.health, (row) => row.id),
        sales: _keepOwn(current.sales, fresh.sales, (row) => row.id),
        expenses: _keepOwn(current.expenses, fresh.expenses, (row) => row.id),
        milk: _keepOwn(current.milk, fresh.milk, (row) => row.id),
      ),
    );
  }

  final book = LocalBookRepository(store: store, userId: () => reader);
  final haveBook = (await book.list()).map((entry) => entry.id).toSet();
  for (final entry in _book(now, now.toUtc())) {
    if (!haveBook.contains(entry.id)) {
      await book.save(entry);
    }
  }

  final feedStore = LocalFeedRepository(store);
  final feed = await feedStore.read();
  final onlyStarter =
      feed.ingredients.every((row) => row.id.startsWith('ing-')) &&
      feed.formulas.every((row) => row.id.startsWith('recipe-')) &&
      feed.batches.every((row) => row.id.startsWith('batch-')) &&
      feed.issues.every((row) => row.id.startsWith('issue-'));
  if (sampleFarm && onlyStarter) {
    await feedStore.write(starterFeedMill(now));
  }
}

List<Animal> _animals(DateTime updatedAt) {
  final herd = <Animal>[];

  Animal pig({
    required String id,
    required String tag,
    required Sex sex,
    required String breed,
    required DateTime born,
    AnimalStatus status = AnimalStatus.onFarm,
    num weightKg = 80,
  }) {
    return Animal(
      id: id,
      tag: tag,
      species: Species.pig,
      sex: sex,
      status: status,
      updatedAt: updatedAt,
      breed: breed,
      dateOfBirth: born,
      weightKg: weightKg.toDouble(),
      locationId: 'piggery',
    );
  }

  for (var number = 1; number <= 380; number++) {
    herd.add(
      pig(
        id: 'sample-sow-$number',
        tag: 'SOW-$number',
        sex: Sex.female,
        breed: pigBreeds[number % pigBreeds.length],
        born: DateTime(
          2022 + (number % 3),
          (number % 12) + 1,
          (number % 27) + 1,
        ),
        weightKg: 150 + (number % 40),
      ),
    );
  }
  for (var number = 1; number <= 20; number++) {
    herd.add(
      pig(
        id: 'sample-boar-$number',
        tag: 'BOAR-$number',
        sex: Sex.male,
        breed: pigBreeds[number % pigBreeds.length],
        born: DateTime(2021 + (number % 3), (number % 12) + 1, 8),
        weightKg: 220 + (number % 30),
      ),
    );
  }
  for (var number = 1; number <= 600; number++) {
    herd.add(
      pig(
        id: 'sample-grower-$number',
        tag: 'GR-$number',
        sex: number.isEven ? Sex.female : Sex.male,
        breed: pigBreeds[number % pigBreeds.length],
        born: DateTime(2026, (number % 6) + 4, (number % 27) + 1),
        weightKg: 18 + (number % 55),
      ),
    );
  }
  herd.add(
    pig(
      id: 'sample-pig-4',
      tag: 'PIG-4',
      sex: Sex.male,
      breed: 'Local',
      born: DateTime(2026, 6, 1),
      status: AnimalStatus.dead,
      weightKg: 18,
    ),
  );
  herd.add(
    pig(
      id: 'sample-pig-8',
      tag: 'PIG-8',
      sex: Sex.female,
      breed: 'Large White',
      born: DateTime(2025, 8, 1),
      status: AnimalStatus.sold,
      weightKg: 86,
    ),
  );
  herd.add(
    pig(
      id: 'sample-pig-9',
      tag: 'PIG-9',
      sex: Sex.male,
      breed: 'Duroc',
      born: DateTime(2025, 7, 1),
      status: AnimalStatus.sold,
      weightKg: 90,
    ),
  );

  const localCattle = ['Sokoto Gudali', 'Sanga', 'West African Shorthorn'];
  for (var number = 1; number <= 90; number++) {
    herd.add(
      Animal(
        id: 'sample-cow-$number',
        tag: 'COW-$number',
        species: Species.cattle,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        updatedAt: updatedAt,
        breed: localCattle[number % localCattle.length],
        dateOfBirth: DateTime(
          2019 + (number % 6),
          (number % 12) + 1,
          (number % 27) + 1,
        ),
        weightKg: 280 + (number % 180).toDouble(),
        locationId: 'cattle_poultry',
      ),
    );
  }
  for (var number = 1; number <= 8; number++) {
    herd.add(
      Animal(
        id: 'sample-bull-$number',
        tag: 'BULL-$number',
        species: Species.cattle,
        sex: Sex.male,
        status: AnimalStatus.onFarm,
        updatedAt: updatedAt,
        breed: localCattle[number % localCattle.length],
        dateOfBirth: DateTime(2018 + (number % 4), 3, 12),
        weightKg: 420 + (number % 80).toDouble(),
        locationId: 'cattle_poultry',
      ),
    );
  }
  herd.add(
    Animal(
      id: 'sample-calf-1',
      tag: 'CALF-1',
      species: Species.cattle,
      sex: Sex.male,
      status: AnimalStatus.onFarm,
      updatedAt: updatedAt,
      breed: 'Sokoto Gudali',
      dateOfBirth: DateTime(2026, 3, 28),
      motherId: 'sample-cow-1',
      fatherId: 'sample-bull-1',
      weightKg: 120,
      locationId: 'cattle_poultry',
    ),
  );
  herd.add(
    Animal(
      id: 'sample-calf-2',
      tag: 'CALF-2',
      species: Species.cattle,
      sex: Sex.female,
      status: AnimalStatus.onFarm,
      updatedAt: updatedAt,
      breed: 'Sanga',
      dateOfBirth: DateTime(2026, 5, 4),
      motherId: 'sample-cow-2',
      weightKg: 95,
      locationId: 'cattle_poultry',
    ),
  );

  for (var number = 1; number <= 20; number++) {
    herd.add(
      Animal(
        id: 'sample-goat-$number',
        tag: 'GOAT-$number',
        species: Species.goat,
        sex: number == 2 ? Sex.male : Sex.female,
        status: AnimalStatus.onFarm,
        updatedAt: updatedAt,
        breed: 'West African Dwarf',
        dateOfBirth: DateTime(2022 + (number % 4), (number % 12) + 1, 10),
        weightKg: 18 + (number % 16).toDouble(),
        locationId: 'cattle_poultry',
      ),
    );
  }
  return herd;
}

List<WeightRecord> _gainWeights(DateTime today, DateTime stamp) {
  final earlier = today.subtract(const Duration(days: 30));
  return [
    WeightRecord(
      id: 'sample-weight-grower-a',
      animalTag: 'GR-1',
      species: Species.pig,
      weighedOn: earlier,
      weightKg: 20,
      updatedAt: stamp,
      sync: SyncState.synced,
    ),
    WeightRecord(
      id: 'sample-weight-grower-b',
      animalTag: 'GR-1',
      species: Species.pig,
      weighedOn: today,
      weightKg: 50,
      updatedAt: stamp,
      sync: SyncState.synced,
    ),
    WeightRecord(
      id: 'sample-weight-layer-a',
      animalTag: 'BIRD-LAYER',
      species: Species.poultry,
      weighedOn: earlier,
      weightKg: 1.2,
      updatedAt: stamp,
      sync: SyncState.synced,
    ),
    WeightRecord(
      id: 'sample-weight-layer-b',
      animalTag: 'BIRD-LAYER',
      species: Species.poultry,
      weighedOn: today,
      weightKg: 1.7,
      updatedAt: stamp,
      sync: SyncState.synced,
    ),
  ];
}

FarmLedger _ledger(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final earlier = _earlierThisMonth(today, 6);
  final monthAgo = today.subtract(const Duration(days: 30));
  final stamp = now.toUtc();

  return FarmLedger(
    births: [
      ..._extraBirths(today, stamp),
      BirthRecord(
        id: 'sample-birth-today',
        happenedOn: today,
        species: Species.pig,
        damTag: 'SOW-1',
        sireTag: 'BOAR-1',
        bornAlive: 10,
        stillborn: 1,
        locationId: 'piggery',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      BirthRecord(
        id: 'sample-birth-sow-2',
        happenedOn: earlier,
        species: Species.pig,
        damTag: 'SOW-2',
        sireTag: 'BOAR-1',
        bornAlive: 8,
        stillborn: 0,
        locationId: 'piggery',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
    ],
    deaths: [
      ..._extraDeaths(today, stamp),
      DeathRecord(
        id: 'sample-death-pig-4',
        happenedOn: earlier,
        animalTag: 'PIG-4',
        species: Species.pig,
        cause: 'Disease',
        locationId: 'piggery',
        ageDays: 40,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
    ],
    feedUses: [
      FeedUse(
        id: 'sample-feed-pigs',
        happenedOn: today,
        locationId: 'piggery',
        species: Species.pig,
        feedType: 'Maize bran',
        quantityKg: 80,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      FeedUse(
        id: 'sample-feed-cattle',
        happenedOn: today,
        locationId: 'cattle_poultry',
        species: Species.cattle,
        feedType: 'Forage',
        quantityKg: 40,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      FeedUse(
        id: 'sample-feed-birds',
        happenedOn: today,
        locationId: 'piggery',
        species: Species.poultry,
        feedType: 'Concentrate',
        quantityKg: 12,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      ..._extraFeedUses(today, stamp),
    ],
    purchases: [
      FeedPurchase(
        id: 'sample-purchase-feed',
        happenedOn: earlier,
        supplier: 'Katamansu mill',
        feedType: 'Concentrate',
        costCedis: 1800,
        quantityKg: 400,
        locationId: 'piggery',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
    ],
    breeding: [
      BreedingService(
        id: 'sample-service-sow-1',
        species: Species.pig,
        damTag: 'SOW-1',
        sireTag: 'BOAR-1',
        serviceKind: ServiceKind.natural,
        servedOn: today.subtract(const Duration(days: 140)),
        expectedOn: today.subtract(const Duration(days: 26)),
        actualOn: today.subtract(const Duration(days: 26)),
        bornAlive: 10,
        stillborn: 1,
        weaned: 9,
        pregnancy: PregnancyCheck.pregnant,
        breed: 'Large White',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      BreedingService(
        id: 'sample-service-sow-2',
        species: Species.pig,
        damTag: 'SOW-2',
        sireTag: 'BOAR-1',
        serviceKind: ServiceKind.natural,
        servedOn: today.subtract(const Duration(days: 111)),
        expectedOn: today.add(const Duration(days: 3)),
        pregnancy: PregnancyCheck.pregnant,
        breed: 'Landrace',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      ..._extraBreeding(today, stamp),
    ],
    weights: [
      WeightRecord(
        id: 'sample-weight-cow-1-a',
        animalTag: 'COW-1',
        species: Species.cattle,
        weighedOn: monthAgo,
        weightKg: 400,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      WeightRecord(
        id: 'sample-weight-cow-1-b',
        animalTag: 'COW-1',
        species: Species.cattle,
        weighedOn: today,
        weightKg: 430,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      WeightRecord(
        id: 'sample-weight-cow-2-a',
        animalTag: 'COW-2',
        species: Species.cattle,
        weighedOn: monthAgo,
        weightKg: 380,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      WeightRecord(
        id: 'sample-weight-cow-2-b',
        animalTag: 'COW-2',
        species: Species.cattle,
        weighedOn: today,
        weightKg: 386,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      WeightRecord(
        id: 'sample-weight-bird-a',
        animalTag: 'BIRD-1',
        species: Species.poultry,
        weighedOn: earlier,
        weightKg: 1.8,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      WeightRecord(
        id: 'sample-weight-bird-b',
        animalTag: 'BIRD-1',
        species: Species.poultry,
        weighedOn: today,
        weightKg: 2.4,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
    ],
    health: [
      HealthEvent(
        id: 'sample-health-sow-1',
        animalTag: 'SOW-1',
        kind: HealthKind.vaccine,
        happenedOn: earlier,
        nextDue: today.add(const Duration(days: 2)),
        note: 'Pig vaccine',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      ..._extraHealth(today, stamp),
    ],
    sales: [
      SaleRecord(
        id: 'sample-sale-pigs',
        happenedOn: today,
        kind: SaleKind.livestock,
        enterprise: Enterprise.pig,
        locationId: 'piggery',
        amountCedis: 2400,
        quantity: 2,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      SaleRecord(
        id: 'sample-sale-beef',
        happenedOn: earlier,
        kind: SaleKind.livestock,
        enterprise: Enterprise.beef,
        locationId: 'cattle_poultry',
        amountCedis: 1800,
        quantity: 1,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      SaleRecord(
        id: 'sample-sale-milk',
        happenedOn: earlier,
        kind: SaleKind.milk,
        enterprise: Enterprise.dairy,
        locationId: 'cattle_poultry',
        amountCedis: 420,
        quantity: 40,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      SaleRecord(
        id: 'sample-sale-birds',
        happenedOn: earlier,
        kind: SaleKind.poultry,
        enterprise: Enterprise.poultry,
        locationId: 'piggery',
        amountCedis: 360,
        quantity: 12,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      SaleRecord(
        id: 'sample-sale-goats',
        happenedOn: earlier,
        kind: SaleKind.livestock,
        enterprise: Enterprise.goat,
        locationId: 'piggery',
        amountCedis: 500,
        quantity: 1,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      ..._extraSales(today, stamp),
    ],
    expenses: _sampleExpenses(now),
    milk: [
      MilkYield(
        id: 'sample-milk-cow-1',
        happenedOn: today,
        cowTag: 'COW-1',
        morningLitres: 8,
        eveningLitres: 6,
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
      ..._extraMilk(today, stamp),
    ],
    land: [
      const LandParcel(
        id: 'sample-land-pasture',
        name: 'Cattle pasture',
        use: LandUse.pasture,
        acres: 10,
      ),
      const LandParcel(
        id: 'sample-land-maize',
        name: 'Maize',
        use: LandUse.maize,
        acres: 4,
        yieldNote: 'For the pigs',
      ),
      const LandParcel(
        id: 'sample-land-napier',
        name: 'Napier grass',
        use: LandUse.napier,
        acres: 4,
      ),
      const LandParcel(
        id: 'sample-land-fallow',
        name: 'Unused',
        use: LandUse.fallow,
        acres: 2,
      ),
    ],
  );
}

/// This month, plus the five months before it.
List<ExpenseRecord> _sampleExpenses(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final stamp = now.toUtc();
  final earlier = _earlierThisMonth(today, 6);

  ExpenseRecord expense({
    required String id,
    required DateTime day,
    required ExpenseCategory category,
    required double amount,
    String note = '',
    double? quantityKg,
    String? feedType,
    String? animalTag,
    int? people,
    double? days,
    double? litres,
    String? detail,
  }) {
    return ExpenseRecord(
      id: id,
      happenedOn: day,
      category: category,
      amountCedis: amount,
      note: note,
      quantityKg: quantityKg,
      feedType: feedType,
      animalTag: animalTag,
      people: people,
      days: days,
      litres: litres,
      detail: detail,
      locationId: 'piggery',
      updatedAt: stamp,
      sync: SyncState.synced,
    );
  }

  final rows = <ExpenseRecord>[
    expense(
      id: 'sample-expense-feed',
      day: earlier,
      category: ExpenseCategory.feed,
      amount: 960,
      note: 'Mill delivery',
      quantityKg: 200,
      feedType: 'Maize bran',
    ),
    expense(
      id: 'sample-expense-vet',
      day: earlier,
      category: ExpenseCategory.vet,
      amount: 80,
      note: 'Dewormer',
      animalTag: 'SOW-1',
      detail: 'Deworming',
    ),
    expense(
      id: 'sample-expense-labour',
      day: earlier,
      category: ExpenseCategory.labour,
      amount: 600,
      note: 'Pen cleaning',
      people: 3,
      days: 2,
    ),
    expense(
      id: 'sample-expense-transport',
      day: earlier,
      category: ExpenseCategory.transport,
      amount: 150,
      detail: 'Madina market',
    ),
    expense(
      id: 'sample-expense-fuel',
      day: earlier,
      category: ExpenseCategory.fuel,
      amount: 220,
      note: 'Farm bike',
      litres: 20,
      detail: 'Diesel',
    ),
    expense(
      id: 'sample-expense-repairs',
      day: earlier,
      category: ExpenseCategory.repairs,
      amount: 90,
      detail: 'Drinker line',
    ),
    expense(
      id: 'sample-expense-other',
      day: earlier,
      category: ExpenseCategory.other,
      amount: 40,
      note: 'Record book',
    ),
  ];

  const history =
      <
        ({
          int feedKg,
          int feedCedis,
          int labour,
          int people,
          int days,
          int fuelLitres,
          int fuelCedis,
          int transport,
          String where,
          int repairs,
          String repair,
          int vet,
          String vetNote,
          String vetTag,
          int other,
          String otherNote,
        })
      >[
        (
          feedKg: 180,
          feedCedis: 860,
          labour: 480,
          people: 2,
          days: 4,
          fuelLitres: 18,
          fuelCedis: 200,
          transport: 120,
          where: 'Abokobi',
          repairs: 0,
          repair: '',
          vet: 0,
          vetNote: '',
          vetTag: '',
          other: 0,
          otherNote: '',
        ),
        (
          feedKg: 220,
          feedCedis: 1050,
          labour: 600,
          people: 3,
          days: 2,
          fuelLitres: 22,
          fuelCedis: 240,
          transport: 0,
          where: '',
          repairs: 70,
          repair: 'North fence',
          vet: 150,
          vetNote: 'Iron',
          vetTag: 'SOW-2',
          other: 0,
          otherNote: '',
        ),
        (
          feedKg: 160,
          feedCedis: 760,
          labour: 480,
          people: 2,
          days: 4,
          fuelLitres: 16,
          fuelCedis: 180,
          transport: 90,
          where: 'Katamansu mill',
          repairs: 0,
          repair: '',
          vet: 0,
          vetNote: '',
          vetTag: '',
          other: 25,
          otherNote: 'Salt lick',
        ),
        (
          feedKg: 240,
          feedCedis: 1140,
          labour: 720,
          people: 4,
          days: 3,
          fuelLitres: 25,
          fuelCedis: 280,
          transport: 0,
          where: '',
          repairs: 110,
          repair: 'Water pump',
          vet: 60,
          vetNote: 'Dewormer',
          vetTag: 'GOAT-1',
          other: 0,
          otherNote: '',
        ),
        (
          feedKg: 200,
          feedCedis: 960,
          labour: 600,
          people: 3,
          days: 2,
          fuelLitres: 20,
          fuelCedis: 220,
          transport: 140,
          where: 'Madina market',
          repairs: 0,
          repair: '',
          vet: 0,
          vetNote: '',
          vetTag: '',
          other: 30,
          otherNote: 'Buckets',
        ),
      ];

  for (var index = 0; index < history.length; index++) {
    final monthsBack = history.length - index;
    final day = DateTime(today.year, today.month - monthsBack, 12);
    final key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
    final month = history[index];
    rows.add(
      expense(
        id: 'sample-expense-feed-$key',
        day: day,
        category: ExpenseCategory.feed,
        amount: month.feedCedis.toDouble(),
        note: 'Mill delivery',
        quantityKg: month.feedKg.toDouble(),
        feedType: switch (index % 3) {
          0 => 'Maize bran',
          1 => 'Soybean meal',
          _ => 'Wheat bran',
        },
      ),
    );
    rows.add(
      expense(
        id: 'sample-expense-labour-$key',
        day: day,
        category: ExpenseCategory.labour,
        amount: month.labour.toDouble(),
        note: 'Yard work',
        people: month.people,
        days: month.days.toDouble(),
      ),
    );
    rows.add(
      expense(
        id: 'sample-expense-fuel-$key',
        day: day,
        category: ExpenseCategory.fuel,
        amount: month.fuelCedis.toDouble(),
        note: 'Farm bike',
        litres: month.fuelLitres.toDouble(),
        detail: index.isEven ? 'Diesel' : 'Petrol',
      ),
    );
    if (month.transport > 0) {
      rows.add(
        expense(
          id: 'sample-expense-transport-$key',
          day: day,
          category: ExpenseCategory.transport,
          amount: month.transport.toDouble(),
          detail: month.where,
        ),
      );
    }
    if (month.repairs > 0) {
      rows.add(
        expense(
          id: 'sample-expense-repairs-$key',
          day: day,
          category: ExpenseCategory.repairs,
          amount: month.repairs.toDouble(),
          detail: month.repair,
        ),
      );
    }
    if (month.vet > 0) {
      rows.add(
        expense(
          id: 'sample-expense-vet-$key',
          day: day,
          category: ExpenseCategory.vet,
          amount: month.vet.toDouble(),
          note: month.vetNote,
          animalTag: month.vetTag,
          detail: month.vetNote.toLowerCase().contains('deworm')
              ? 'Deworming'
              : 'Vaccination',
        ),
      );
    }
    if (month.other > 0) {
      rows.add(
        expense(
          id: 'sample-expense-other-$key',
          day: day,
          category: ExpenseCategory.other,
          amount: month.other.toDouble(),
          note: month.otherNote,
        ),
      );
    }
  }
  _fillExpenses(rows, expense, today, stamp);
  return rows;
}

void _fillExpenses(
  List<ExpenseRecord> rows,
  ExpenseRecord Function({
    required String id,
    required DateTime day,
    required ExpenseCategory category,
    required double amount,
    String note,
    double? quantityKg,
    String? feedType,
    String? animalTag,
    int? people,
    double? days,
    double? litres,
    String? detail,
  })
  expense,
  DateTime today,
  DateTime stamp,
) {
  final start = DateTime(today.year, today.month - 5, 1);
  final span = today.difference(start).inDays;
  final need = 1000 - rows.length;
  if (need <= 0) {
    return;
  }
  const notes = [
    'Mill delivery',
    'Dewormer',
    'Yard work',
    'Market run',
    'Farm bike',
    'Fence repair',
    'Record book',
  ];
  const feeds = ['Maize bran', 'Concentrate', 'Wheat bran'];
  for (var index = 0; index < need; index++) {
    final category =
        ExpenseCategory.values[index % ExpenseCategory.values.length];
    final day = start.add(
      Duration(days: span == 0 ? 0 : (index * span) ~/ need),
    );
    final amount = (40 + (index * 17) % 1600).toDouble();
    final goat = index % 5 == 0;
    rows.add(
      expense(
        id: 'sample-expense-bulk-$index',
        day: day,
        category: category,
        amount: amount,
        note: notes[index % notes.length],
        quantityKg: category == ExpenseCategory.feed
            ? (80 + (index % 220)).toDouble()
            : null,
        feedType: category == ExpenseCategory.feed
            ? feeds[index % feeds.length]
            : null,
        animalTag: category == ExpenseCategory.vet
            ? (goat ? 'GOAT-${(index % 20) + 1}' : 'SOW-${(index % 40) + 1}')
            : null,
        people: category == ExpenseCategory.labour ? 2 + (index % 4) : null,
        days: category == ExpenseCategory.labour
            ? (1 + (index % 3)).toDouble()
            : null,
        litres: category == ExpenseCategory.fuel
            ? (10 + (index % 30)).toDouble()
            : null,
        detail: category == ExpenseCategory.transport
            ? 'Madina market'
            : category == ExpenseCategory.repairs
            ? 'Pen ${index % 12}'
            : null,
      ),
    );
  }
}

DateTime _spread(DateTime today, int index, int count) {
  final start = DateTime(today.year, today.month - 5, 1);
  final span = today.difference(start).inDays;
  var day = start.add(Duration(days: span == 0 ? 0 : (index * span) ~/ count));
  if (!day.isBefore(today)) {
    day = today.subtract(const Duration(days: 1));
  }
  return day;
}

List<BirthRecord> _extraBirths(DateTime today, DateTime stamp) {
  return [
    for (var index = 0; index < 36; index++)
      BirthRecord(
        id: 'sample-birth-bulk-$index',
        happenedOn: _spread(today, index, 36),
        species: index % 4 == 0 ? Species.goat : Species.pig,
        damTag: index % 4 == 0
            ? 'GOAT-${(index % 20) + 1}'
            : 'SOW-${(index % 30) + 3}',
        sireTag: index % 4 == 0 ? 'GOAT-2' : 'BOAR-1',
        bornAlive: index % 4 == 0 ? 2 : 6 + (index % 4),
        stillborn: index % 9 == 0 ? 1 : 0,
        locationId: index % 4 == 0 ? 'cattle_poultry' : 'piggery',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<DeathRecord> _extraDeaths(DateTime today, DateTime stamp) {
  const causes = ['Disease', 'Injury', 'Age', 'Unknown'];
  return [
    for (var index = 0; index < 48; index++)
      DeathRecord(
        id: 'sample-death-bulk-$index',
        happenedOn: _spread(today, index, 48),
        animalTag: switch (index % 3) {
          0 => 'GOAT-${(index % 20) + 1}',
          1 => 'COW-${(index % 40) + 1}',
          _ => 'GR-${(index % 80) + 1}',
        },
        species: switch (index % 3) {
          0 => Species.goat,
          1 => Species.cattle,
          _ => Species.pig,
        },
        cause: causes[index % causes.length],
        locationId: index % 3 == 2 ? 'piggery' : 'cattle_poultry',
        ageDays: 20 + (index % 200),
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<HealthEvent> _extraHealth(DateTime today, DateTime stamp) {
  const kinds = [HealthKind.vaccine, HealthKind.deworm, HealthKind.treatment];
  return [
    for (var index = 0; index < 80; index++)
      HealthEvent(
        id: 'sample-health-bulk-$index',
        animalTag: index % 3 == 0
            ? 'GOAT-${(index % 20) + 1}'
            : index % 3 == 1
            ? 'COW-${(index % 40) + 1}'
            : 'SOW-${(index % 40) + 1}',
        kind: kinds[index % kinds.length],
        happenedOn: _spread(today, index, 80),
        nextDue: index == 0 ? today.add(const Duration(days: 4)) : null,
        note: index % 3 == 0 ? 'Goat vaccine' : 'Herd treatment',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<BreedingService> _extraBreeding(DateTime today, DateTime stamp) {
  return [
    for (var index = 0; index < 12; index++)
      BreedingService(
        id: 'sample-service-goat-$index',
        species: Species.goat,
        damTag: 'GOAT-${index + 1}',
        sireTag: 'GOAT-2',
        serviceKind: ServiceKind.natural,
        servedOn: today.subtract(Duration(days: 150 - index)),
        expectedOn: index == 0
            ? today.add(const Duration(days: 6))
            : today.subtract(Duration(days: 30 + index)),
        actualOn: index == 0
            ? null
            : today.subtract(Duration(days: 30 + index)),
        bornAlive: index == 0 ? null : 2,
        stillborn: 0,
        weaned: index == 0 ? null : 2,
        pregnancy: PregnancyCheck.pregnant,
        breed: 'West African Dwarf',
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<MilkYield> _extraMilk(DateTime today, DateTime stamp) {
  return [
    for (var monthsBack = 1; monthsBack <= 5; monthsBack++)
      for (final cow in ['COW-1', 'COW-2'])
        MilkYield(
          id: 'sample-milk-$cow-$monthsBack',
          happenedOn: DateTime(today.year, today.month - monthsBack, 8),
          cowTag: cow,
          morningLitres: 6 + (monthsBack % 3).toDouble(),
          eveningLitres: 4 + (monthsBack % 2).toDouble(),
          updatedAt: stamp,
          sync: SyncState.synced,
        ),
  ];
}

List<FeedUse> _extraFeedUses(DateTime today, DateTime stamp) {
  const kinds = [
    (Species.pig, 'Maize bran', 'piggery'),
    (Species.cattle, 'Forage', 'cattle_poultry'),
    (Species.goat, 'Napier', 'cattle_poultry'),
  ];
  return [
    for (var index = 0; index < 60; index++)
      FeedUse(
        id: 'sample-feed-bulk-$index',
        happenedOn: _spread(today, index, 60),
        locationId: kinds[index % 3].$3,
        species: kinds[index % 3].$1,
        feedType: kinds[index % 3].$2,
        quantityKg: (15 + (index % 40)).toDouble(),
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<SaleRecord> _extraSales(DateTime today, DateTime stamp) {
  final start = DateTime(today.year, today.month - 5, 1);
  final span = today.difference(start).inDays;
  const enterprises = [
    Enterprise.pig,
    Enterprise.beef,
    Enterprise.dairy,
    Enterprise.goat,
    Enterprise.poultry,
  ];
  const kinds = [
    SaleKind.livestock,
    SaleKind.livestock,
    SaleKind.milk,
    SaleKind.livestock,
    SaleKind.poultry,
  ];
  return [
    for (var index = 0; index < 995; index++)
      SaleRecord(
        id: 'sample-sale-bulk-$index',
        happenedOn: start.add(
          Duration(days: span == 0 ? 0 : (index * span) ~/ 995),
        ),
        kind: kinds[index % kinds.length],
        enterprise: enterprises[index % enterprises.length],
        locationId: index.isEven ? 'piggery' : 'cattle_poultry',
        amountCedis: (80 + (index * 23) % 4000).toDouble(),
        quantity: (1 + (index % 12)).toDouble(),
        updatedAt: stamp,
        sync: SyncState.synced,
      ),
  ];
}

List<FarmEntry> _book(DateTime now, DateTime updatedAt) {
  final today = DateTime(now.year, now.month, now.day);
  final earlier = _earlierThisMonth(today, 6);
  return [
    FarmEntry(
      id: 'sample-book-birth',
      kind: BookKind.breeding,
      happenedOn: today,
      animalTag: 'SOW-1',
      note: '10 piglets born alive',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-feed',
      kind: BookKind.feed,
      happenedOn: today,
      note: '80 kg maize bran for the pigs',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-milk',
      kind: BookKind.milk,
      happenedOn: today,
      animalTag: 'COW-1',
      note: 'Morning and evening',
      amount: 14,
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-sale',
      kind: BookKind.sale,
      happenedOn: today,
      animalTag: 'PIG-9',
      note: 'Two pigs to market',
      amount: 2400,
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-health',
      kind: BookKind.health,
      happenedOn: earlier,
      animalTag: 'SOW-1',
      note: 'Dewormer',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-death',
      kind: BookKind.death,
      happenedOn: earlier,
      animalTag: 'PIG-4',
      note: 'Disease',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-goat-health',
      kind: BookKind.health,
      happenedOn: earlier,
      animalTag: 'GOAT-1',
      note: 'Goat vaccine',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-goat-birth',
      kind: BookKind.breeding,
      happenedOn: earlier,
      animalTag: 'GOAT-3',
      note: '2 kids born',
      updatedAt: updatedAt,
    ),
    FarmEntry(
      id: 'sample-book-goat-death',
      kind: BookKind.death,
      happenedOn: earlier,
      animalTag: 'GOAT-8',
      note: 'Injury',
      updatedAt: updatedAt,
    ),
  ];
}

DateTime _earlierThisMonth(DateTime today, int daysBack) {
  final shifted = today.subtract(Duration(days: daysBack));
  if (shifted.year != today.year || shifted.month != today.month) {
    return DateTime(today.year, today.month, 1);
  }
  return shifted;
}
