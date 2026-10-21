import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/traceability.dart';

void main() {
  test('forecast follows the recent change and stays at zero or above', () {
    expect(forecastNext([10, 20, 30]), 40);
    expect(forecastNext([30, 10, 0]), 0);
    expect(forecastNext([]), 0);
  });

  test('expenses in the month are grouped by category', () {
    final today = DateTime(2026, 10, 20);
    final ledger = FarmLedger.empty.copyWith(
      expenses: [
        _expense('a', ExpenseCategory.feed, 100, DateTime(2026, 10, 2)),
        _expense('b', ExpenseCategory.feed, 40, DateTime(2026, 10, 3)),
        _expense('c', ExpenseCategory.vet, 25, DateTime(2026, 9, 3)),
        _expense('d', ExpenseCategory.fuel, 15, DateTime(2026, 10, 8)),
      ],
    );
    final groups = expensesByCategory(ledger, today, FarmPeriod.month);
    expect(groups.map((slice) => slice.label), ['Feed', 'Fuel']);
    expect(groups.first.value, 140);
  });

  test('a custom range keeps only the dates inside it', () {
    final window = ChartWindow(
      start: DateTime(2026, 10, 1),
      end: DateTime(2026, 10, 10),
    );
    expect(window.contains(DateTime(2026, 10, 1)), isTrue);
    expect(window.contains(DateTime(2026, 10, 10)), isTrue);
    expect(window.contains(DateTime(2026, 10, 11)), isFalse);
  });

  test('home events for today leave out last week and hide money', () {
    final today = DateTime(2026, 10, 20);
    final ledger = FarmLedger.empty.copyWith(
      births: [
        BirthRecord(
          id: 'b',
          happenedOn: today,
          species: Species.pig,
          damTag: 'SOW-1',
          bornAlive: 1,
          stillborn: 0,
          locationId: 'piggery',
          updatedAt: today,
        ),
      ],
      sales: [
        SaleRecord(
          id: 's',
          happenedOn: today,
          kind: SaleKind.livestock,
          enterprise: Enterprise.pig,
          locationId: 'piggery',
          amountCedis: 80,
          updatedAt: today,
        ),
      ],
      deaths: [
        DeathRecord(
          id: 'd',
          happenedOn: today.subtract(const Duration(days: 3)),
          animalTag: 'PIG-1',
          species: Species.pig,
          cause: 'Age',
          locationId: 'piggery',
          updatedAt: today,
        ),
      ],
    );
    final todayOnly = recentFarmEvents(
      ledger: ledger,
      today: today,
      thisWeek: false,
      showMoney: false,
    );
    expect(todayOnly.map((event) => event.title), ['Birth']);
    final week = recentFarmEvents(
      ledger: ledger,
      today: today,
      thisWeek: true,
      showMoney: true,
    );
    expect(week.map((event) => event.title), ['Birth', 'Sale', 'Death']);
  });

  test('yesterday, last week, and pig classes use the farm records', () {
    final today = DateTime(2026, 10, 21);
    final yesterday = presetWindow(ChartPreset.yesterday, today);
    expect(yesterday.start, DateTime(2026, 10, 20));
    expect(yesterday.end, DateTime(2026, 10, 20));
    final lastWeek = presetWindow(ChartPreset.lastWeek, today);
    expect(
      lastWeek.end.isBefore(presetWindow(ChartPreset.week, today).start),
      isTrue,
    );

    final pigs = pigPopulation([
      _pig('SOW-1', Sex.female),
      _pig('BOAR-1', Sex.male),
      _pig('GR-1', Sex.male),
      _pig('PIGLET-1', Sex.female, born: DateTime(2026, 10, 1)),
    ], today);
    expect(pigs.map((slice) => slice.label), [
      'Sows',
      'Boars',
      'Growers',
      'Piglets',
    ]);
  });

  test('profit and feed charts use the selected dates', () {
    final today = DateTime(2026, 10, 21);
    final window = presetWindow(ChartPreset.year, today);
    final ledger = FarmLedger.empty.copyWith(
      sales: [
        SaleRecord(
          id: 'sale',
          happenedOn: DateTime(2026, 10, 2),
          kind: SaleKind.livestock,
          enterprise: Enterprise.pig,
          locationId: 'piggery',
          amountCedis: 500,
          updatedAt: DateTime(2026, 10, 2),
        ),
      ],
      expenses: [
        _expense('feed', ExpenseCategory.feed, 100, DateTime(2026, 10, 2)),
      ],
      feedUses: [
        FeedUse(
          id: 'use',
          happenedOn: DateTime(2026, 10, 2),
          locationId: 'piggery',
          species: Species.pig,
          feedType: 'Maize',
          quantityKg: 10,
          updatedAt: DateTime(2026, 10, 2),
        ),
      ],
    );
    final profit = profitByEnterprise(ledger, window);
    expect(profit.single.label, 'Piggery');
    expect(profit.single.value, 400);

    final mill = starterFeedMill(today);
    expect(feedProduced(mill, window), isNotEmpty);
    expect(feedIssuedStacks(mill, window), isNotEmpty);
  });
}

Animal _pig(String tag, Sex sex, {DateTime? born}) {
  return Animal(
    id: tag,
    tag: tag,
    species: Species.pig,
    sex: sex,
    status: AnimalStatus.onFarm,
    updatedAt: DateTime.utc(2026, 10, 21),
    dateOfBirth: born,
  );
}

ExpenseRecord _expense(
  String id,
  ExpenseCategory category,
  double amount,
  DateTime day,
) {
  return ExpenseRecord(
    id: id,
    happenedOn: day,
    category: category,
    amountCedis: amount,
    locationId: 'piggery',
    updatedAt: day,
    quantityKg: category == ExpenseCategory.feed ? 10 : null,
    feedType: category == ExpenseCategory.feed ? 'Maize' : null,
    litres: category == ExpenseCategory.fuel ? 5 : null,
  );
}
