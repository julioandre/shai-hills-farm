import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/data/local_feed_repository.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/feed_screen.dart';
import 'package:shai_hills_farm/ui/money_screen.dart';

void main() {
  test('a recipe prices each ingredient and the cost per kg', () {
    final today = DateTime(2026, 10, 20);
    var mill = FeedMill.empty;
    mill = buyIngredient(
      mill,
      _ingredient('maize', 'Maize', 100, 2),
      today,
    ).mill;
    mill = buyIngredient(
      mill,
      _ingredient('sbm', 'Soybean Meal', 100, 4),
      today,
    ).mill;
    mill = saveFormula(
      mill,
      const FeedFormula(
        id: 'grower',
        name: 'Pig Grower',
        lines: [
          FormulaLine(ingredientName: 'Maize', quantityKg: 60),
          FormulaLine(ingredientName: 'Soybean Meal', quantityKg: 40),
        ],
      ),
    ).mill;
    final price = priceFormula(mill.formulas.single, mill);
    expect(price.totalKg, 100);
    expect(price.totalCost, 280);
    expect(price.costPerKg, 2.8);
    expect(price.lines.first.percent, 0.6);
    expect(price.lines.first.cost, 120);
  });

  test('mixing reduces stock and refuses a short ingredient', () {
    final today = DateTime(2026, 10, 20);
    var mill = FeedMill.empty;
    mill = buyIngredient(
      mill,
      _ingredient('maize', 'Maize', 10, 2),
      today,
    ).mill;
    mill = saveFormula(
      mill,
      const FeedFormula(
        id: 'grower',
        name: 'Pig Grower',
        lines: [FormulaLine(ingredientName: 'Maize', quantityKg: 10)],
      ),
    ).mill;
    final mixed = mixFeed(
      mill,
      id: 'batch-1',
      number: 'FD-1',
      formulaId: 'grower',
      quantityKg: 4,
      producedOn: today,
      producedBy: 'Ama',
      today: today,
    );
    expect(mixed.error, isNull);
    expect(mixed.mill.ingredients.single.stockKg, 6);
    expect(mixed.mill.batches.single.costPerKg, 2);
    expect(mixed.mill.batches.single.cost, 8);

    final refused = mixFeed(
      mixed.mill,
      id: 'batch-2',
      number: 'FD-2',
      formulaId: 'grower',
      quantityKg: 20,
      producedOn: today,
      producedBy: 'Ama',
      today: today,
    );
    expect(refused.error, contains('Not enough Maize'));
    expect(refused.mill.batches, hasLength(1));
  });

  test('giving out feed stops at what the batch has left', () {
    final today = DateTime(2026, 10, 20);
    var mill = FeedMill.empty;
    mill = buyIngredient(
      mill,
      _ingredient('maize', 'Maize', 50, 2),
      today,
    ).mill;
    mill = saveFormula(
      mill,
      const FeedFormula(
        id: 'grower',
        name: 'Pig Grower',
        lines: [FormulaLine(ingredientName: 'Maize', quantityKg: 10)],
      ),
    ).mill;
    mill = mixFeed(
      mill,
      id: 'batch-1',
      number: 'FD-1',
      formulaId: 'grower',
      quantityKg: 10,
      producedOn: today,
      producedBy: 'Ama',
      today: today,
    ).mill;
    mill = giveFeed(
      mill,
      FeedIssue(
        id: 'issue-1',
        batchId: 'batch-1',
        issuedOn: today,
        species: Species.pig,
        pen: 'Grower Pen A',
        group: 'Growers',
        quantityKg: 6,
      ),
      today,
    ).mill;
    expect(remainingKg(mill, 'batch-1'), 4);
    final refused = giveFeed(
      mill,
      FeedIssue(
        id: 'issue-2',
        batchId: 'batch-1',
        issuedOn: today,
        species: Species.pig,
        pen: 'Grower Pen A',
        group: 'Growers',
        quantityKg: 5,
      ),
      today,
    );
    expect(refused.error, contains('4 kg'));
  });

  test('the starter mill alerts on limestone and rates the groups', () {
    final today = DateTime(2026, 10, 20);
    final mill = starterFeedMill(today);
    final saved = FeedMill.fromJson(mill.toJson());
    expect(saved.batches, hasLength(4));
    expect(
      saved.ingredients.firstWhere((row) => row.name == 'Maize').stockKg,
      1898,
    );
    expect(lowStock(saved).map((row) => row.name), ['Limestone']);
    final grower = saved.formulas.firstWhere((row) => row.name == 'Pig Grower');
    expect(priceFormula(grower, saved).costPerKg, closeTo(4.31, 0.001));

    final stamp = DateTime.utc(2026, 10, 20);
    final report = feedReport(
      mill: saved,
      weights: [
        _weight('GR-1', Species.pig, DateTime(2026, 9, 20), 20, stamp),
        _weight('GR-1', Species.pig, today, 50, stamp),
        _weight('BIRD-1', Species.poultry, DateTime(2026, 10, 1), 1.8, stamp),
        _weight('BIRD-1', Species.poultry, today, 2.4, stamp),
        _weight(
          'BIRD-LAYER',
          Species.poultry,
          DateTime(2026, 10, 1),
          1.2,
          stamp,
        ),
        _weight('BIRD-LAYER', Species.poultry, today, 1.7, stamp),
        _weight('COW-1', Species.cattle, DateTime(2026, 9, 20), 400, stamp),
        _weight('COW-1', Species.cattle, today, 430, stamp),
      ],
      milk: [
        MilkYield(
          id: 'milk',
          happenedOn: today,
          cowTag: 'COW-1',
          morningLitres: 8,
          eveningLitres: 6,
          updatedAt: stamp,
        ),
      ],
      salesByLabel: const {'Piggery': 2400},
    );
    final pigs = report.scores.firstWhere((row) => row.name == 'Pigs');
    final broilers = report.scores.firstWhere((row) => row.name == 'Broilers');
    final layers = report.scores.firstWhere((row) => row.name == 'Layers');
    final dairy = report.scores.firstWhere((row) => row.name == 'Dairy');
    expect(pigs.fcr, closeTo(3, 0.001));
    expect(pigs.costPerResult, closeTo(12.93, 0.01));
    expect(broilers.fcr, closeTo(3, 0.001));
    expect(layers.fcr, closeTo(4, 0.001));
    expect(dairy.fcr, closeTo(3, 0.001));
    expect(report.best!.fcr, closeTo(3, 0.001));
    expect(report.worst!.pen, 'Layer House');
    expect(
      report.money.firstWhere((row) => row.enterprise == 'Piggery').sales,
      2400,
    );
    final trend = feedTrend(saved, today);
    expect(trend.last.producedKg, greaterThan(0));
    expect(
      consumptionByEnterprise(saved).map((row) => row.label),
      containsAll(['Pigs', 'Broilers', 'Layers', 'Dairy']),
    );
    final animals = feedGivenBySpecies(saved);
    expect(animals.map((row) => row.label), ['Pigs', 'Cattle', 'Poultry']);
    expect(animals.first.kg, 90);
    expect(animals[1].kg, 42);
    expect(animals[2].kg, 3.8);
    expect(feedGivenByGroup(saved).map((row) => '${row.label} ${row.kg}'), [
      'Growers 90.0',
      'Dairy 42.0',
      'Layers 2.0',
      'Broilers 1.8',
    ]);
    expect(feedGivenByPen(saved).first.label, 'Grower Pen A');
    final onHand = mixturesOnHand(saved);
    expect(onHand.map((row) => row.batch.number), ['FD-3', 'FD-4', 'FD-1']);
    expect(onHand.first.leftKg, closeTo(18.2, 0.001));
    expect(onHand.last.leftKg, 10);

    final afterUse = stockAfterUse(saved, [
      FeedUse(
        id: 'use-grower',
        happenedOn: today,
        locationId: 'piggery',
        species: Species.pig,
        feedType: 'Pig Grower',
        quantityKg: 4,
        updatedAt: stamp,
      ),
      FeedUse(
        id: 'use-maize',
        happenedOn: today,
        locationId: 'piggery',
        species: Species.pig,
        feedType: 'Maize',
        quantityKg: 10,
        updatedAt: stamp,
      ),
      FeedUse(
        id: 'use-other',
        happenedOn: today,
        locationId: 'piggery',
        species: Species.goat,
        feedType: 'Maize bran',
        quantityKg: 100,
        updatedAt: stamp,
      ),
    ]);
    final maize = afterUse.ingredients.firstWhere(
      (row) => row.ingredient.name == 'Maize',
    );
    expect(maize.leftKg, closeTo(1888, 0.001));
    expect(maize.usedKg, 10);
    expect(
      afterUse.mixtures.firstWhere((row) => row.batch.number == 'FD-1').leftKg,
      6,
    );
    expect(afterUse.shortKg, 100);
  });

  test('a formula keeps its own stock and scales a 100 kg mix', () {
    final today = DateTime(2026, 10, 20);
    final template = formulaTemplates['Pig Grower']!;
    final formula = FeedFormula(
      id: 'grower',
      name: 'Pig Grower',
      minimumKg: 20,
      lines: [
        for (final line in template)
          FormulaLine(ingredientName: line.$1, quantityKg: line.$2),
      ],
    );
    expect(formula.totalKg, 100);
    var mill = FeedMill.empty;
    mill = buyIngredient(
      mill,
      _ingredient('maize', 'Maize', 400, 3),
      today,
    ).mill;
    mill = saveFormula(mill, formula).mill;
    expect(mill.ingredients.map((row) => row.name), contains('Wheat Bran'));
    expect(
      mill.ingredients.firstWhere((row) => row.name == 'Wheat Bran').stockKg,
      0,
    );
    expect(finishedFeed(mill).single.leftKg, 0);
    expect(finishedFeed(mill).single.low, isTrue);

    final plan = planMix(mill, formula, 1000);
    expect(plan.lines.firstWhere((row) => row.name == 'Maize').needKg, 550);
    expect(plan.error, contains('Not enough Maize'));

    mill = buyIngredient(
      mill,
      _ingredient('bran', 'Wheat Bran', 100, 2),
      today,
    ).mill;
    mill = buyIngredient(
      mill,
      _ingredient('pkc', 'Palm Kernel Cake', 200, 2),
      today,
    ).mill;
    mill = buyIngredient(
      mill,
      _ingredient('sbm', 'Soybean Meal', 300, 4),
      today,
    ).mill;
    mill = buyIngredient(
      mill,
      _ingredient('premix', 'Premix', 50, 10),
      today,
    ).mill;
    mill = buyIngredient(mill, _ingredient('salt', 'Salt', 30, 1), today).mill;
    mill = buyIngredient(
      mill,
      _ingredient('maize-more', 'Maize', 200, 3),
      today,
    ).mill;
    final mixed = mixFeed(
      mill,
      id: 'batch-1',
      number: 'FD-1',
      formulaId: 'grower',
      quantityKg: 1000,
      producedOn: today,
      producedBy: 'Ama',
      today: today,
    );
    expect(mixed.error, isNull);
    expect(finishedFeed(mixed.mill).single.leftKg, 1000);
    expect(
      mixed.mill.ingredients.firstWhere((row) => row.name == 'Maize').stockKg,
      50,
    );

    final given = giveFinishedFeed(
      mixed.mill,
      id: 'out-1',
      formulaName: 'Pig Grower',
      quantityKg: 300,
      issuedOn: today,
      species: Species.pig,
      pen: 'Grower Pen A',
      group: 'Growers',
      today: today,
    );
    expect(given.error, isNull);
    expect(finishedFeed(given.mill).single.leftKg, 700);
    expect(given.mill.issues.single.quantityKg, 300);
  });

  testWidgets('buying maize puts it in the store', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final feed = FeedController(LocalFeedRepository(MemoryStore()));
    await feed.load();
    final ledger = LedgerController(
      LocalLedgerRepository(MemoryStore()),
      LocalSyncTarget(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: FeedScreen(
            feed: feed,
            ledger: ledger,
            showMoney: true,
            canManage: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('feed-buy')), findsNothing);
    expect(
      find.text('No ingredients yet. Record a feed expense on Money.'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: MoneyScreen(ledger: ledger, feed: feed),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('expense-feed')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense-item-name')),
      'Maize bran',
    );
    await tester.enterText(find.byKey(const Key('expense-kilos')), '40');
    await tester.enterText(find.byKey(const Key('expense-amount')), '120');
    await tester.enterText(find.byKey(const Key('expense-supplier')), 'Kofi');
    await tester.ensureVisible(find.byKey(const Key('save-expense')));
    await tester.tap(find.byKey(const Key('save-expense')));
    await tester.pumpAndSettle();

    expect(feed.mill.ingredients.single.name, 'Maize bran');
    expect(feed.mill.ingredients.single.stockKg, 40);
    expect(feed.mill.ingredients.single.supplier, 'Kofi');
    expect(ledger.ledger.expenses.single.itemName, 'Maize bran');
    expect(ledger.ledger.expenses.single.quantityKg, 40);
  });
}

FeedIngredient _ingredient(String id, String name, double kg, double cost) {
  return FeedIngredient(
    id: id,
    name: name,
    stockKg: kg,
    unitCost: cost,
    supplier: 'Tema mill',
    purchasedOn: DateTime(2026, 10, 1),
    minimumKg: 5,
  );
}

WeightRecord _weight(
  String tag,
  Species species,
  DateTime day,
  double kg,
  DateTime stamp,
) {
  return WeightRecord(
    id: '$tag-${day.day}',
    animalTag: tag,
    species: species,
    weighedOn: day,
    weightKg: kg,
    updatedAt: stamp,
  );
}
