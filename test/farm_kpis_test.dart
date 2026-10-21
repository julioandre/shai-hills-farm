import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/role.dart';

void main() {
  final today = DateTime(2026, 10, 20);

  test('roles hide money from workers and leave recording open', () {
    const worker = FarmAccess(FarmRole.worker);
    const manager = FarmAccess(FarmRole.manager);
    const admin = FarmAccess(FarmRole.admin);

    expect(worker.viewFinancials, isFalse);
    expect(worker.manageUsers, isFalse);
    expect(worker.recordBirths, isTrue);
    expect(worker.recordFeedUse, isTrue);
    expect(manager.viewFinancials, isTrue);
    expect(manager.manageUsers, isFalse);
    expect(manager.manageFeedPurchases, isTrue);
    expect(admin.manageUsers, isTrue);
    expect(admin.viewFinancials, isTrue);
  });

  test('kpis answer where money, feed, sows, cattle, and deaths stand', () {
    final kpis = FarmKpis.evaluate(
      animals: [
        _animal('pig-1'),
        _animal('pig-2'),
        _animal('cow-1', Species.cattle),
      ],
      ledger: FarmLedger(
        births: [_birth('SOW-1', 10), _birth('SOW-2', 6)],
        deaths: [
          DeathRecord(
            id: 'd1',
            happenedOn: today,
            animalTag: 'PIG-9',
            species: Species.pig,
            cause: 'Disease',
            locationId: 'main',
            updatedAt: today,
          ),
        ],
        feedUses: [
          _feed(Species.pig, 400),
          _feed(Species.cattle, 100),
          _feed(Species.poultry, 50),
        ],
        purchases: [
          FeedPurchase(
            id: 'buy',
            happenedOn: today,
            supplier: 'Katamansu mill',
            feedType: 'Maize bran',
            costCedis: 2000,
            quantityKg: 1000,
            locationId: 'main',
            updatedAt: today,
          ),
        ],
        breeding: [
          BreedingService(
            id: 'serve',
            species: Species.pig,
            damTag: 'SOW-1',
            serviceKind: ServiceKind.natural,
            servedOn: DateTime(2026, 6, 1),
            expectedOn: DateTime(2026, 10, 23),
            bornAlive: 10,
            weaned: 9,
            updatedAt: today,
          ),
        ],
        weights: [
          _weight('COW-1', Species.cattle, DateTime(2026, 10, 1), 200),
          _weight('COW-1', Species.cattle, DateTime(2026, 10, 31), 230),
          _weight('BIRD-1', Species.poultry, DateTime(2026, 10, 1), 1),
          _weight('BIRD-1', Species.poultry, DateTime(2026, 10, 20), 26),
        ],
        health: [
          HealthEvent(
            id: 'vac',
            animalTag: 'SOW-1',
            kind: HealthKind.vaccine,
            happenedOn: DateTime(2026, 10, 1),
            nextDue: today,
            note: 'Vaccine',
            updatedAt: today,
          ),
        ],
        sales: [_sale(Enterprise.pig, 5000), _sale(Enterprise.beef, 1000)],
        milk: [
          MilkYield(
            id: 'milk',
            happenedOn: today,
            cowTag: 'COW-1',
            morningLitres: 8,
            eveningLitres: 4,
            updatedAt: today,
          ),
        ],
      ),
      today: today,
    );

    expect(kpis.birthsToday, 2);
    expect(kpis.deathsToday, 1);
    expect(kpis.feedKgToday, 550);
    expect(kpis.revenue, 6000);
    expect(kpis.feedCost, 2000);
    expect(kpis.grossMargin, 4000);
    expect(kpis.feedCostRatio, closeTo(2000 / 6000, 0.001));
    expect(kpis.bestEnterprise, Enterprise.pig);
    expect(kpis.worstEnterprise, Enterprise.beef);
    expect(kpis.spentToday, 2000);
    expect(kpis.profitToday, 4000);
    expect(kpis.sowScores.first.damTag, 'SOW-1');
    expect(kpis.sowScores.first.score, 10);
    expect(kpis.pigletsPerLitter, 8);
    expect(kpis.weaningRate, 0.9);
    expect(kpis.farrowingRate, 1);
    expect(kpis.cattleGains.single.animalTag, 'COW-1');
    expect(kpis.cattleGains.single.gainPerDay, 1);
    expect(kpis.cattleGains.single.underperforming, isFalse);
    expect(kpis.mortalityRate, closeTo(1 / 4, 0.001));
    expect(kpis.litresPerCow, 12);
    expect(kpis.poultryFcr, 2);
    expect(kpis.attention.map((item) => item.title), [
      'Vaccine due',
      'Expected farrowing',
    ]);
  });
}

Animal _animal(String id, [Species species = Species.pig]) {
  return Animal(
    id: id,
    tag: id,
    species: species,
    sex: Sex.female,
    status: AnimalStatus.onFarm,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

BirthRecord _birth(String dam, int alive) {
  return BirthRecord(
    id: dam,
    happenedOn: DateTime(2026, 10, 20),
    species: Species.pig,
    damTag: dam,
    bornAlive: alive,
    stillborn: 0,
    locationId: 'main',
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

FeedUse _feed(Species species, double kg) {
  return FeedUse(
    id: species.wire,
    happenedOn: DateTime(2026, 10, 20),
    locationId: 'main',
    species: species,
    feedType: 'Maize bran',
    quantityKg: kg,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

WeightRecord _weight(String tag, Species species, DateTime day, double kg) {
  return WeightRecord(
    id: '$tag-${day.day}',
    animalTag: tag,
    species: species,
    weighedOn: day,
    weightKg: kg,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}

SaleRecord _sale(Enterprise enterprise, double cedis) {
  return SaleRecord(
    id: enterprise.wire,
    happenedOn: DateTime(2026, 10, 20),
    kind: SaleKind.livestock,
    enterprise: enterprise,
    locationId: 'main',
    amountCedis: cedis,
    updatedAt: DateTime.utc(2026, 10, 20),
  );
}
