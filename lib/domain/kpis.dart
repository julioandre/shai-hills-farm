import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

/// Answers the questions Katamansu management asks every week.
///
/// Money is revenue minus feed cost and other expenses. Feed is the cost this farm can waste.
/// A sow's score is the average piglets born alive in her litters.
/// Cattle performance is average daily gain between the first and last weigh-in.
/// Mortality is deaths this month divided by the animals still on the farm
/// plus those deaths. Rates are omitted when the farm has not recorded the
/// numbers yet.
class FarmKpis {
  const FarmKpis({
    required this.birthsToday,
    required this.deathsToday,
    required this.salesToday,
    required this.spentToday,
    required this.feedKgToday,
    required this.revenue,
    required this.feedCost,
    required this.expenses,
    required this.mortalityRate,
    required this.feedCostRatio,
    required this.grossMargin,
    required this.bestEnterprise,
    required this.worstEnterprise,
    required this.revenueByEnterprise,
    required this.sowScores,
    required this.cattleGains,
    required this.pigletsPerLitter,
    required this.weaningRate,
    required this.farrowingRate,
    required this.litresPerCow,
    required this.poultryFcr,
    required this.attention,
    required this.mortalityBySpecies,
  });

  final int birthsToday;
  final int deathsToday;
  final double salesToday;

  /// Feed purchases and other costs recorded today.
  final double spentToday;
  final double feedKgToday;
  final double revenue;
  final double feedCost;
  final double expenses;

  /// Null when there is no herd and no deaths to measure.
  final double? mortalityRate;
  final double? feedCostRatio;
  final double grossMargin;
  final Enterprise? bestEnterprise;

  /// The weakest enterprise that also brought money in this month.
  final Enterprise? worstEnterprise;

  double get profitToday => salesToday - spentToday;
  final Map<Enterprise, double> revenueByEnterprise;
  final List<SowScore> sowScores;
  final List<CattleGain> cattleGains;
  final double? pigletsPerLitter;
  final double? weaningRate;
  final double? farrowingRate;
  final double? litresPerCow;
  final double? poultryFcr;
  final List<FarmAttention> attention;
  final Map<Species, double> mortalityBySpecies;

  factory FarmKpis.evaluate({
    required Iterable<Animal> animals,
    required FarmLedger ledger,
    required DateTime today,
  }) {
    final pigLitters = [
      for (final row in ledger.births)
        if (row.species == Species.pig && row.damTag.trim().isNotEmpty) row,
    ];
    final monthDeaths = [
      for (final row in ledger.deaths)
        if (sameMonth(row.happenedOn, today)) row,
    ];
    final monthSales = [
      for (final row in ledger.sales)
        if (sameMonth(row.happenedOn, today)) row,
    ];
    final monthFeed = [
      for (final row in ledger.feedUses)
        if (sameMonth(row.happenedOn, today)) row,
    ];
    final monthPurchases = [
      for (final row in ledger.purchases)
        if (sameMonth(row.happenedOn, today)) row,
    ];
    final monthMilk = [
      for (final row in ledger.milk)
        if (sameMonth(row.happenedOn, today)) row,
    ];

    final revenueByEnterprise = {for (final e in Enterprise.values) e: 0.0};
    var revenue = 0.0;
    var salesToday = 0.0;
    for (final sale in monthSales) {
      revenue += sale.amountCedis;
      revenueByEnterprise[sale.enterprise] =
          (revenueByEnterprise[sale.enterprise] ?? 0) + sale.amountCedis;
      if (sameDay(sale.happenedOn, today)) {
        salesToday += sale.amountCedis;
      }
    }

    final monthExpenses = [
      for (final row in ledger.expenses)
        if (sameMonth(row.happenedOn, today)) row,
    ];
    var feedCost = 0.0;
    var otherExpenses = 0.0;
    for (final purchase in monthPurchases) {
      feedCost += purchase.costCedis;
    }
    for (final expense in monthExpenses) {
      if (expense.category == ExpenseCategory.feed) {
        feedCost += expense.amountCedis;
      } else {
        otherExpenses += expense.amountCedis;
      }
    }
    final expenseTotal = monthExpenses.fold<double>(
      0,
      (sum, row) => sum + row.amountCedis,
    );

    final feedKgBySpecies = {
      for (final species in Species.values) species: 0.0,
    };
    var feedKgToday = 0.0;
    var feedKg = 0.0;
    for (final use in monthFeed) {
      feedKg += use.quantityKg;
      feedKgBySpecies[use.species] =
          (feedKgBySpecies[use.species] ?? 0) + use.quantityKg;
      if (sameDay(use.happenedOn, today)) {
        feedKgToday += use.quantityKg;
      }
    }

    final cattleEnterprise =
        (revenueByEnterprise[Enterprise.dairy] ?? 0) >
            (revenueByEnterprise[Enterprise.beef] ?? 0)
        ? Enterprise.dairy
        : Enterprise.beef;
    final marginByEnterprise = {for (final e in Enterprise.values) e: 0.0};
    for (final enterprise in Enterprise.values) {
      final share = feedKg == 0
          ? 0.0
          : _feedKgFor(enterprise, feedKgBySpecies, cattleEnterprise) / feedKg;
      marginByEnterprise[enterprise] =
          (revenueByEnterprise[enterprise] ?? 0) - feedCost * share;
    }
    Enterprise? best;
    var bestMargin = 0.0;
    for (final entry in marginByEnterprise.entries) {
      if (entry.value > bestMargin) {
        bestMargin = entry.value;
        best = entry.key;
      }
    }
    Enterprise? worst;
    var worstMargin = double.infinity;
    var withSales = 0;
    for (final entry in marginByEnterprise.entries) {
      if ((revenueByEnterprise[entry.key] ?? 0) <= 0) {
        continue;
      }
      withSales += 1;
      if (entry.value < worstMargin) {
        worstMargin = entry.value;
        worst = entry.key;
      }
    }
    if (withSales < 2 || worst == best) {
      worst = null;
    }
    var spentToday = 0.0;
    for (final expense in monthExpenses) {
      if (sameDay(expense.happenedOn, today)) {
        spentToday += expense.amountCedis;
      }
    }
    for (final purchase in monthPurchases) {
      if (sameDay(purchase.happenedOn, today)) {
        spentToday += purchase.costCedis;
      }
    }

    final onFarm = {for (final species in Species.values) species: 0};
    for (final animal in animals) {
      if (animal.status == AnimalStatus.onFarm) {
        onFarm[animal.species] = (onFarm[animal.species] ?? 0) + 1;
      }
    }
    final deathsBySpecies = {for (final species in Species.values) species: 0};
    for (final death in monthDeaths) {
      deathsBySpecies[death.species] =
          (deathsBySpecies[death.species] ?? 0) + 1;
    }
    final mortalityBySpecies = <Species, double>{};
    var herd = 0;
    var deaths = 0;
    for (final species in Species.values) {
      final alive = onFarm[species] ?? 0;
      final lost = deathsBySpecies[species] ?? 0;
      herd += alive;
      deaths += lost;
      final base = alive + lost;
      if (base > 0 && lost > 0) {
        mortalityBySpecies[species] = lost / base;
      }
    }

    return FarmKpis(
      birthsToday: ledger.births
          .where((row) => sameDay(row.happenedOn, today))
          .length,
      deathsToday: ledger.deaths
          .where((row) => sameDay(row.happenedOn, today))
          .length,
      salesToday: salesToday,
      spentToday: spentToday,
      feedKgToday: feedKgToday,
      revenue: revenue,
      feedCost: feedCost,
      expenses: expenseTotal,
      mortalityRate: herd + deaths == 0 ? null : deaths / (herd + deaths),
      feedCostRatio: revenue <= 0 ? null : feedCost / revenue,
      grossMargin: revenue - feedCost - otherExpenses,
      bestEnterprise: best,
      worstEnterprise: worst,
      revenueByEnterprise: revenueByEnterprise,
      sowScores: _sows(pigLitters),
      cattleGains: _gains(ledger.weights, Species.cattle),
      pigletsPerLitter: pigLitters.isEmpty
          ? null
          : pigLitters.fold<int>(0, (sum, row) => sum + row.bornAlive) /
                pigLitters.length,
      weaningRate: _weaningRate(ledger.breeding),
      farrowingRate: _farrowingRate(ledger),
      litresPerCow: _litresPerCow(monthMilk),
      poultryFcr: _fcr(monthFeed, ledger.weights),
      attention: _attention(ledger, today),
      mortalityBySpecies: mortalityBySpecies,
    );
  }
}

class SowScore {
  const SowScore({
    required this.damTag,
    required this.litters,
    required this.bornAlive,
    required this.weaned,
  });

  final String damTag;
  final int litters;
  final double bornAlive;
  final double weaned;

  /// Piglets born alive per litter. This is the ranking number.
  double get score => bornAlive;
}

class CattleGain {
  const CattleGain({
    required this.animalTag,
    required this.gainPerDay,
    required this.underperforming,
  });

  final String animalTag;
  final double gainPerDay;

  /// Below 0.5 kg a day on this farm.
  final bool underperforming;
}

class FarmAttention {
  const FarmAttention({required this.title, required this.detail});

  final String title;
  final String detail;
}

List<SowScore> _sows(List<BirthRecord> litters) {
  final grouped = <String, List<BirthRecord>>{};
  for (final litter in litters) {
    grouped.putIfAbsent(litter.damTag, () => []).add(litter);
  }
  final scores = [
    for (final entry in grouped.entries)
      SowScore(
        damTag: entry.key,
        litters: entry.value.length,
        bornAlive:
            entry.value.fold<int>(0, (sum, row) => sum + row.bornAlive) /
            entry.value.length,
        weaned: 0,
      ),
  ];
  scores.sort((a, b) => b.score.compareTo(a.score));
  return scores;
}

double? _weaningRate(List<BreedingService> services) {
  var born = 0;
  var weaned = 0;
  var counted = false;
  for (final service in services) {
    if (service.species != Species.pig || service.weaned == null) {
      continue;
    }
    counted = true;
    born += service.bornAlive ?? 0;
    weaned += service.weaned ?? 0;
  }
  if (!counted || born == 0) {
    return null;
  }
  return weaned / born;
}

double? _farrowingRate(FarmLedger ledger) {
  final served = ledger.breeding.where((row) => row.species == Species.pig);
  final servedCount = served.length;
  if (servedCount == 0) {
    return null;
  }
  final dams = {for (final row in served) row.damTag};
  final farrowed = ledger.births
      .where((row) => row.species == Species.pig && dams.contains(row.damTag))
      .map((row) => row.damTag)
      .toSet()
      .length;
  return farrowed / servedCount;
}

List<CattleGain> _gains(List<WeightRecord> weights, Species species) {
  final grouped = <String, List<WeightRecord>>{};
  for (final row in weights) {
    if (row.species == species) {
      grouped.putIfAbsent(row.animalTag, () => []).add(row);
    }
  }
  final gains = <CattleGain>[];
  for (final entry in grouped.entries) {
    final rows = [...entry.value]
      ..sort((a, b) => a.weighedOn.compareTo(b.weighedOn));
    if (rows.length < 2) {
      continue;
    }
    final days = rows.last.weighedOn.difference(rows.first.weighedOn).inDays;
    if (days <= 0) {
      continue;
    }
    final gain = (rows.last.weightKg - rows.first.weightKg) / days;
    gains.add(
      CattleGain(
        animalTag: entry.key,
        gainPerDay: gain,
        underperforming: gain < 0.5,
      ),
    );
  }
  gains.sort((a, b) => b.gainPerDay.compareTo(a.gainPerDay));
  return gains;
}

double? _litresPerCow(List<MilkYield> yields) {
  if (yields.isEmpty) {
    return null;
  }
  final cows = yields.map((row) => row.cowTag).toSet();
  if (cows.isEmpty) {
    return null;
  }
  final litres = yields.fold<double>(0, (sum, row) => sum + row.litres);
  return litres / cows.length;
}

double? _fcr(List<FeedUse> feed, List<WeightRecord> weights) {
  final poultryFeed = feed
      .where((row) => row.species == Species.poultry)
      .fold<double>(0, (sum, row) => sum + row.quantityKg);
  final grouped = <String, List<WeightRecord>>{};
  for (final row in weights) {
    if (row.species == Species.poultry) {
      grouped.putIfAbsent(row.animalTag, () => []).add(row);
    }
  }
  var gained = 0.0;
  for (final rows in grouped.values) {
    final ordered = [...rows]
      ..sort((a, b) => a.weighedOn.compareTo(b.weighedOn));
    if (ordered.length < 2) {
      continue;
    }
    gained += ordered.last.weightKg - ordered.first.weightKg;
  }
  if (poultryFeed <= 0 || gained <= 0) {
    return null;
  }
  return poultryFeed / gained;
}

List<FarmAttention> _attention(FarmLedger ledger, DateTime today) {
  final start = DateTime(today.year, today.month, today.day);
  final horizon = start.add(const Duration(days: 7));
  final items = <FarmAttention>[];
  for (final event in ledger.health) {
    final due = event.nextDue;
    if (due == null) {
      continue;
    }
    final day = DateTime(due.year, due.month, due.day);
    if (day.isAfter(horizon) ||
        day.isBefore(start.subtract(const Duration(days: 1)))) {
      continue;
    }
    items.add(
      FarmAttention(title: '${event.kind.label} due', detail: event.animalTag),
    );
  }
  for (final service in ledger.breeding) {
    if (service.actualOn != null) {
      continue;
    }
    final due = DateTime(
      service.expectedOn.year,
      service.expectedOn.month,
      service.expectedOn.day,
    );
    if (due.isAfter(horizon) || due.isBefore(start)) {
      continue;
    }
    final title = service.species == Species.pig
        ? 'Expected farrowing'
        : service.species == Species.cattle
        ? 'Expected calving'
        : 'Expected birth';
    items.add(FarmAttention(title: title, detail: service.damTag));
  }
  return items;
}

double _feedKgFor(
  Enterprise enterprise,
  Map<Species, double> feed,
  Enterprise cattleEnterprise,
) {
  return switch (enterprise) {
    Enterprise.pig => feed[Species.pig] ?? 0,
    Enterprise.beef || Enterprise.dairy =>
      enterprise == cattleEnterprise ? feed[Species.cattle] ?? 0 : 0,
    Enterprise.poultry => feed[Species.poultry] ?? 0,
    Enterprise.goat => (feed[Species.goat] ?? 0) + (feed[Species.sheep] ?? 0),
    Enterprise.general => 0,
  };
}
