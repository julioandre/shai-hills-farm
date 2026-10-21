import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/app/app_backend.dart';
import 'package:shai_hills_farm/app/farm_app.dart';
import 'package:shai_hills_farm/data/local_animal_repository.dart';
import 'package:shai_hills_farm/data/local_ledger_repository.dart';
import 'package:shai_hills_farm/data/memory_store.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/sync_target.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/money_screen.dart';

void main() {
  test('an expense stays on the phone and comes off the margin', () async {
    final repository = LocalLedgerRepository(MemoryStore());
    final today = DateTime(2026, 10, 20);
    await repository.addSale(
      SaleRecord(
        id: 'sale-1',
        happenedOn: today,
        kind: SaleKind.livestock,
        enterprise: Enterprise.pig,
        locationId: 'main',
        amountCedis: 500,
        updatedAt: today,
      ),
    );
    await repository.addExpense(
      ExpenseRecord(
        id: 'cost-1',
        happenedOn: today,
        category: ExpenseCategory.vet,
        amountCedis: 80,
        note: 'Dewormer',
        locationId: 'main',
        updatedAt: today,
      ),
    );

    final ledger = await repository.read();
    expect(ledger.expenses.single.note, 'Dewormer');
    expect(ledger.pendingCount, 2);

    final feedGap = expenseProblem(
      ExpenseRecord(
        id: 'cost-feed',
        happenedOn: today,
        category: ExpenseCategory.feed,
        amountCedis: 90,
        locationId: 'main',
        updatedAt: today,
      ),
    );
    expect(feedGap, 'Enter the kilos.');
    await repository.addExpense(
      ExpenseRecord(
        id: 'cost-feed',
        happenedOn: today,
        category: ExpenseCategory.feed,
        amountCedis: 90,
        quantityKg: 200,
        feedType: 'Maize bran',
        locationId: 'main',
        updatedAt: today,
      ),
    );
    final withFeed = await repository.read();
    final feed = withFeed.expenses.singleWhere((row) => row.id == 'cost-feed');
    expect(feed.quantityKg, 200);
    expect(feed.summary, 'Feed · Maize bran · 200 kg');

    final kpis = FarmKpis.evaluate(
      animals: const <Animal>[],
      ledger: ledger,
      today: today,
    );
    expect(kpis.revenue, 500);
    expect(kpis.expenses, 80);
    expect(kpis.grossMargin, 420);
  });

  testWidgets('admin records an expense and reads the sales report', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(FarmApp(backend: AppBackend.local(MemoryStore())));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.enterText(find.byKey(const Key('phone-field')), '0244120008');
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('code-field')), '123456');
    await tester.tap(find.byKey(const Key('submit-auth')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-money')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('expense-item-name')),
      'Dewormer',
    );
    await tester.enterText(find.byKey(const Key('expense-quantity')), '2');
    await tester.enterText(find.byKey(const Key('expense-amount')), '40');
    await tester.enterText(find.byKey(const Key('expense-note')), 'Dewormer');
    await tester.ensureVisible(find.byKey(const Key('save-expense')));
    await tester.tap(find.byKey(const Key('save-expense')));
    await tester.pumpAndSettle();
    expect(find.textContaining('GH₵ 40'), findsWidgets);

    await tester.tap(find.byKey(const Key('money-sales')));
    await tester.pumpAndSettle();
    expect(find.text('No sales this month yet.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('sale-item-name')), 'Pig');
    await tester.enterText(find.byKey(const Key('sale-quantity')), '1');
    await tester.enterText(find.byKey(const Key('money-sale-amount')), '250');
    await tester.ensureVisible(find.byKey(const Key('save-sale')));
    await tester.tap(find.byKey(const Key('save-sale')));
    await tester.pumpAndSettle();
    expect(find.text('GH₵ 250'), findsWidgets);
    expect(find.byKey(const Key('sales-pig')), findsOneWidget);
  });

  testWidgets('a livestock sale marks that animal sold', (tester) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemoryStore();
    final herd = HerdController(
      LocalAnimalRepository(store: store, userId: () => 'user'),
    );
    final saved = await herd.save(
      Animal(
        id: 'pig-1',
        tag: 'SOW-1',
        species: Species.pig,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        updatedAt: DateTime.utc(2026, 10, 21),
      ),
    );
    expect(saved, isNull);
    final ledger = LedgerController(
      LocalLedgerRepository(store),
      LocalSyncTarget(),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: farmTheme(),
        home: Scaffold(
          body: MoneyScreen(ledger: ledger, herd: herd),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('money-sales')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sale-item-name')), 'Sow');
    await tester.enterText(find.byKey(const Key('sale-quantity')), '1');
    await tester.enterText(find.byKey(const Key('sale-animal')), 'SOW-1');
    await tester.enterText(find.byKey(const Key('sale-weight')), '80');
    await tester.enterText(find.byKey(const Key('sale-cost')), '15');
    await tester.enterText(find.byKey(const Key('money-sale-amount')), '900');
    await tester.ensureVisible(find.byKey(const Key('save-sale')));
    await tester.tap(find.byKey(const Key('save-sale')));
    await tester.pumpAndSettle();

    final animal = herd.animals.single;
    expect(animal.status, AnimalStatus.sold);
    expect(animal.saleWeightKg, 80);
    expect(animal.salePrice, 900);
    expect(animal.saleCost, 15);
    expect(ledger.ledger.sales.single.animalTag, 'SOW-1');
  });
}
