import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/traceability.dart';

/// One labelled amount for a chart slice or bar.
class ChartSlice {
  const ChartSlice(this.label, this.value);

  final String label;
  final double value;
}

/// Sales and expenses in one stretch of time.
class MoneyBucket {
  const MoneyBucket({
    required this.label,
    required this.sales,
    required this.expenses,
  });

  final String label;
  final double sales;
  final double expenses;
}

enum InsightTone { healthy, watch, critical }

/// Which pictures the charts page is allowed to show.
enum ChartTopic { livestock, health, sales, expenses, feed }

/// Date chips on the charts page, including the previous stretch.
enum ChartPreset {
  today,
  yesterday,
  week,
  lastWeek,
  month,
  lastMonth,
  quarter,
  year,
  threeMonths,
}

/// The dates for a chart chip. Custom ranges stay on [windowFor].
ChartWindow presetWindow(ChartPreset preset, DateTime today) {
  final end = DateTime(today.year, today.month, today.day);
  return switch (preset) {
    ChartPreset.today => ChartWindow(start: end, end: end),
    ChartPreset.yesterday => ChartWindow(
      start: end.subtract(const Duration(days: 1)),
      end: end.subtract(const Duration(days: 1)),
    ),
    ChartPreset.week => windowFor(FarmPeriod.week, today),
    ChartPreset.lastWeek => _previousWeek(end),
    ChartPreset.month => windowFor(FarmPeriod.month, today),
    ChartPreset.lastMonth => _previousMonth(end),
    ChartPreset.quarter => windowFor(FarmPeriod.quarter, today),
    ChartPreset.year => windowFor(FarmPeriod.year, today),
    ChartPreset.threeMonths => ChartWindow(
      start: DateTime(end.year, end.month - 2, 1),
      end: end,
    ),
  };
}

ChartWindow _previousWeek(DateTime end) {
  final monday = end.subtract(Duration(days: end.weekday - 1));
  final start = monday.subtract(const Duration(days: 7));
  return ChartWindow(
    start: start,
    end: monday.subtract(const Duration(days: 1)),
  );
}

ChartWindow _previousMonth(DateTime end) {
  final start = DateTime(end.year, end.month - 1);
  final last = DateTime(end.year, end.month, 0);
  return ChartWindow(start: start, end: last);
}

/// Inclusive start and end for a chart filter.
class ChartWindow {
  const ChartWindow({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool contains(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final from = DateTime(start.year, start.month, start.day);
    final to = DateTime(end.year, end.month, end.day);
    return !date.isBefore(from) && !date.isAfter(to);
  }
}

/// The dates behind a period chip, or a chosen custom range.
ChartWindow windowFor(
  FarmPeriod period,
  DateTime today, {
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final end = DateTime(today.year, today.month, today.day);
  if (customStart != null && customEnd != null) {
    var from = DateTime(customStart.year, customStart.month, customStart.day);
    var to = DateTime(customEnd.year, customEnd.month, customEnd.day);
    if (from.isAfter(to)) {
      final swap = from;
      from = to;
      to = swap;
    }
    if (to.isAfter(end)) {
      to = end;
    }
    return ChartWindow(start: from, end: to);
  }
  final start = switch (period) {
    FarmPeriod.today => end,
    FarmPeriod.week => end.subtract(Duration(days: end.weekday - 1)),
    FarmPeriod.month => DateTime(end.year, end.month),
    FarmPeriod.quarter => DateTime(end.year, ((end.month - 1) ~/ 3) * 3 + 1),
    FarmPeriod.year => DateTime(end.year),
  };
  return ChartWindow(start: start, end: end);
}

class FarmInsight {
  const FarmInsight({
    required this.title,
    required this.detail,
    required this.tone,
    required this.topic,
  });

  final String title;
  final String detail;
  final InsightTone tone;
  final ChartTopic topic;
}

/// One thing that happened on the farm, for the home list.
class HomeEvent {
  const HomeEvent({
    required this.day,
    required this.title,
    required this.detail,
  });

  final DateTime day;
  final String title;
  final String detail;
}

enum HerdGroup { species, sex, status }

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Next value if the recent change continues. Never below zero.
double forecastNext(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  if (values.length == 1) {
    return values.last < 0 ? 0 : values.last;
  }
  final start = values.length <= 4 ? 1 : values.length - 3;
  var change = 0.0;
  var steps = 0;
  for (var i = start; i < values.length; i++) {
    change += values[i] - values[i - 1];
    steps += 1;
  }
  final next = values.last + (steps == 0 ? 0 : change / steps);
  return next < 0 ? 0 : next;
}

List<ChartSlice> herdSlices(
  List<Animal> animals,
  HerdGroup group, {
  Species? species,
}) {
  final rows = [
    for (final animal in animals)
      if (species == null || animal.species == species)
        if (group == HerdGroup.status || animal.status == AnimalStatus.onFarm)
          animal,
  ];
  final counts = <String, double>{};
  for (final animal in rows) {
    final label = switch (group) {
      HerdGroup.species => animal.species.plural,
      HerdGroup.sex => animal.sex.label,
      HerdGroup.status => animal.status.label,
    };
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final order = switch (group) {
    HerdGroup.species => [for (final item in Species.values) item.plural],
    HerdGroup.sex => [for (final item in Sex.values) item.label],
    HerdGroup.status => [for (final item in AnimalStatus.values) item.label],
  };
  return [
    for (final label in order)
      if ((counts[label] ?? 0) > 0) ChartSlice(label, counts[label]!),
  ];
}

/// How one species is split on the home page.
List<ChartSlice> speciesPicture(List<Animal> animals, Species species) {
  final onFarm = [
    for (final animal in animals)
      if (animal.species == species && animal.status == AnimalStatus.onFarm)
        animal,
  ];
  if (species == Species.cattle) {
    final dairy = onFarm.where((animal) => animal.dairy).length;
    return [
      if (dairy > 0) ChartSlice('Dairy', dairy.toDouble()),
      if (onFarm.length - dairy > 0)
        ChartSlice('Beef', (onFarm.length - dairy).toDouble()),
    ];
  }
  if (species == Species.poultry) {
    final breeds = <String, int>{};
    for (final animal in onFarm) {
      final breed = (animal.breed ?? '').trim();
      final label = breed.isEmpty ? 'Birds' : breed;
      breeds[label] = (breeds[label] ?? 0) + 1;
    }
    return [
      for (final entry in breeds.entries)
        ChartSlice(entry.key, entry.value.toDouble()),
    ];
  }
  final females = onFarm.where((animal) => animal.sex == Sex.female).length;
  final males = onFarm.length - females;
  final female = species == Species.pig ? 'Sows and gilts' : 'Female';
  final male = species == Species.pig ? 'Boars' : 'Male';
  return [
    if (females > 0) ChartSlice(female, females.toDouble()),
    if (males > 0) ChartSlice(male, males.toDouble()),
  ];
}

List<MoneyBucket> moneyBuckets(
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  final days = range.end.difference(range.start).inDays;
  if (days <= 0) {
    return [_span('Today', ledger, range.start, range.end)];
  }
  if (days <= 16) {
    return _days(ledger, range.start, range.end);
  }
  if (days <= 62) {
    return _weeks(ledger, range.start, range.end);
  }
  return _months(ledger, range.start, range.end);
}

List<ChartSlice> salesByEnterprise(
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  final totals = <Enterprise, double>{};
  for (final sale in ledger.sales) {
    if (!range.contains(sale.happenedOn)) {
      continue;
    }
    totals[sale.enterprise] = (totals[sale.enterprise] ?? 0) + sale.amountCedis;
  }
  return [
    for (final enterprise in Enterprise.values)
      if ((totals[enterprise] ?? 0) > 0)
        ChartSlice(enterprise.label, totals[enterprise]!),
  ];
}

List<ChartSlice> expensesByCategory(
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  final totals = <ExpenseCategory, double>{};
  for (final expense in ledger.expenses) {
    if (!range.contains(expense.happenedOn)) {
      continue;
    }
    totals[expense.category] =
        (totals[expense.category] ?? 0) + expense.amountCedis;
  }
  return [
    for (final category in ExpenseCategory.values)
      if ((totals[category] ?? 0) > 0)
        ChartSlice(category.label, totals[category]!),
  ];
}

/// Feed types, vet kinds, and fuel types, so a bill is not only "Feed" or "Vet".
List<ChartSlice> expensesByItem(
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  final totals = <String, double>{};
  for (final expense in ledger.expenses) {
    if (!range.contains(expense.happenedOn)) {
      continue;
    }
    final label = expense.itemLabel;
    totals[label] = (totals[label] ?? 0) + expense.amountCedis;
  }
  final slices = [
    for (final entry in totals.entries) ChartSlice(entry.key, entry.value),
  ]..sort((a, b) => b.value.compareTo(a.value));
  return slices;
}

List<ChartSlice> deathsBySpecies(
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  Species? species,
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  final totals = <Species, double>{};
  for (final death in ledger.deaths) {
    if (species != null && death.species != species) {
      continue;
    }
    if (!range.contains(death.happenedOn)) {
      continue;
    }
    totals[death.species] = (totals[death.species] ?? 0) + 1;
  }
  return [
    for (final item in Species.values)
      if ((totals[item] ?? 0) > 0) ChartSlice(item.plural, totals[item]!),
  ];
}

List<ChartSlice> healthSlices(
  List<Animal> animals,
  FarmLedger ledger,
  DateTime today,
  FarmPeriod period, {
  Species? species,
  ChartWindow? window,
}) {
  final range = window ?? windowFor(period, today);
  var vaccines = 0.0;
  var sickness = 0.0;
  for (final event in ledger.health) {
    if (!range.contains(event.happenedOn)) {
      continue;
    }
    if (species != null && !_tagSpecies(animals, event.animalTag, species)) {
      continue;
    }
    if (event.kind == HealthKind.vaccine) {
      vaccines += 1;
    } else {
      sickness += 1;
    }
  }
  return [
    if (vaccines > 0) ChartSlice('Vaccinations', vaccines),
    if (sickness > 0) ChartSlice('Sickness', sickness),
  ];
}

({List<HealthEvent> vaccines, List<HealthEvent> sickness}) animalHealth(
  String tag,
  FarmLedger ledger,
) {
  final wanted = tag.trim().toLowerCase();
  final matches = [
    for (final event in ledger.health)
      if (event.animalTag.trim().toLowerCase() == wanted) event,
  ]..sort((a, b) => b.happenedOn.compareTo(a.happenedOn));
  return (
    vaccines: [
      for (final event in matches)
        if (event.kind == HealthKind.vaccine) event,
    ],
    sickness: [
      for (final event in matches)
        if (event.kind != HealthKind.vaccine) event,
    ],
  );
}

List<FarmInsight> farmInsights({
  required List<Animal> animals,
  required FarmLedger ledger,
  required DateTime today,
  required FarmPeriod period,
  required bool showMoney,
  ChartWindow? window,
  FeedMill? mill,
}) {
  final range = window ?? windowFor(period, today);
  final insights = <FarmInsight>[];
  final onFarm = animals
      .where((animal) => animal.status == AnimalStatus.onFarm)
      .length;
  final deaths = ledger.deaths
      .where((row) => range.contains(row.happenedOn))
      .length;
  if (onFarm == 0) {
    insights.add(
      const FarmInsight(
        title: 'No animals on the farm',
        detail: 'Register the herd so the charts have something to show.',
        tone: InsightTone.critical,
        topic: ChartTopic.livestock,
      ),
    );
  } else if (deaths == 0) {
    insights.add(
      const FarmInsight(
        title: 'No deaths in this period',
        detail: 'Mortality is clear for the dates you are looking at.',
        tone: InsightTone.healthy,
        topic: ChartTopic.health,
      ),
    );
  } else {
    final rate = deaths / onFarm * 100;
    final counted = <Species, int>{};
    for (final row in ledger.deaths) {
      if (range.contains(row.happenedOn)) {
        counted[row.species] = (counted[row.species] ?? 0) + 1;
      }
    }
    final parts = [
      for (final species in Species.values)
        if ((counted[species] ?? 0) > 0)
          '${counted[species]} ${counted[species] == 1 ? species.singular : species.plural.toLowerCase()}',
    ];
    insights.add(
      FarmInsight(
        title: deaths == 1 ? '1 death' : '$deaths deaths',
        detail: rate < 1
            ? '${parts.join(', ')}. Under 1% of the animals still on the farm.'
            : '${parts.join(', ')}. ${rate.round()}% of the animals still on the farm.',
        tone: rate >= 5 ? InsightTone.critical : InsightTone.watch,
        topic: ChartTopic.health,
      ),
    );
  }

  final due = [
    for (final event in ledger.health)
      if (event.nextDue != null &&
          DateTime(
            event.nextDue!.year,
            event.nextDue!.month,
            event.nextDue!.day,
          ).isBefore(DateTime(today.year, today.month, today.day)))
        event,
  ];
  if (due.isNotEmpty) {
    insights.add(
      FarmInsight(
        title: due.length == 1
            ? '1 vaccination is overdue'
            : '${due.length} vaccinations are overdue',
        detail: due.first.animalTag,
        tone: InsightTone.critical,
        topic: ChartTopic.health,
      ),
    );
  }

  if (!showMoney) {
    return insights;
  }

  final sales = salesByEnterprise(ledger, today, period, window: range);
  if (sales.isNotEmpty) {
    final best = sales.reduce((a, b) => a.value >= b.value ? a : b);
    insights.add(
      FarmInsight(
        title: '${best.label} leads sales',
        detail:
            '${formatCedis(best.value)} came in from ${best.label.toLowerCase()} in this period.',
        tone: InsightTone.healthy,
        topic: ChartTopic.sales,
      ),
    );
  }
  final costs = expensesByItem(ledger, today, period, window: range);
  if (costs.isNotEmpty) {
    final total = costs.fold<double>(0, (sum, slice) => sum + slice.value);
    final top = costs.reduce((a, b) => a.value >= b.value ? a : b);
    final share = total == 0 ? 0 : top.value / total * 100;
    insights.add(
      FarmInsight(
        title: '${top.label} is the biggest cost',
        detail:
            '${formatCedis(top.value)} on ${top.label.toLowerCase()}, ${share.round()}% of spending.',
        tone: share >= 60 ? InsightTone.watch : InsightTone.healthy,
        topic: ChartTopic.expenses,
      ),
    );
  }

  final buckets = moneyBuckets(ledger, today, period, window: range);
  if (buckets.length >= 2) {
    final nextSales = forecastNext([for (final row in buckets) row.sales]);
    final nextCosts = forecastNext([for (final row in buckets) row.expenses]);
    final last = buckets.last;
    insights.add(
      FarmInsight(
        title: nextSales >= last.sales
            ? 'Sales look steady or rising'
            : 'Sales look lower next period',
        detail: nextCosts > last.expenses
            ? 'Next stretch is about ${formatCedis(nextSales)} in and ${formatCedis(nextCosts)} out.'
            : 'Next stretch is about ${formatCedis(nextSales)} in. Spending is not climbing with it.',
        tone: nextSales >= last.sales && nextCosts <= last.expenses * 1.1
            ? InsightTone.healthy
            : InsightTone.watch,
        topic: ChartTopic.sales,
      ),
    );
  }

  if (mill != null) {
    final given = [
      for (final issue in mill.issues)
        if (range.contains(issue.issuedOn)) issue,
    ];
    final kilos = given.fold<double>(0, (sum, row) => sum + row.quantityKg);
    if (kilos > 0) {
      final report = feedReport(
        mill: mill,
        weights: ledger.weights,
        milk: ledger.milk,
        salesByLabel: {
          for (final slice in salesByEnterprise(
            ledger,
            today,
            period,
            window: range,
          ))
            slice.label: slice.value,
        },
      );
      final working = [
        for (final score in report.scores)
          if (score.feedKg > 0 && score.fcr != null) score,
      ];
      if (working.isEmpty) {
        insights.add(
          FarmInsight(
            title: 'Feed is going out',
            detail:
                '${formatKg(kilos)} given out. Weigh the animals twice, or record the milk, to see if it is paying off.',
            tone: InsightTone.watch,
            topic: ChartTopic.feed,
          ),
        );
      } else {
        final best = working.reduce((a, b) => a.fcr! <= b.fcr! ? a : b);
        final result = best.perLitre
            ? '${_oneDecimal(best.fcr!)} kg of feed for each litre of milk'
            : '${_oneDecimal(best.fcr!)} kg of feed for each kg gained';
        insights.add(
          FarmInsight(
            title: '${best.name} is using the feed best',
            detail: '${formatKg(kilos)} given out in this period. $result.',
            tone: InsightTone.healthy,
            topic: ChartTopic.feed,
          ),
        );
      }
    }
  }
  return insights;
}

double _oneDecimal(double value) {
  return (value * 10).round() / 10;
}

/// One card in the animals strip. A non-empty [slices] list is a pie.
class HerdCard {
  const HerdCard({
    required this.title,
    required this.detail,
    this.slices = const [],
  });

  final String title;
  final String detail;
  final List<ChartSlice> slices;
}

/// One row of herd facts. All species stay broad. One species gets finer cards.
List<HerdCard> herdCards({
  required List<Animal> animals,
  required FarmLedger ledger,
  required ChartWindow window,
  Species? species,
}) {
  final onFarm = [
    for (final animal in animals)
      if (animal.status == AnimalStatus.onFarm &&
          (species == null || animal.species == species))
        animal,
  ];
  if (species == null) {
    return [
      _countCard('Born', _born(ledger, window, null)),
      HerdCard(
        title: 'Herd',
        detail: onFarm.isEmpty
            ? 'None on the farm'
            : '${onFarm.length} on the farm',
        slices: herdSlices(animals, HerdGroup.species),
      ),
      _countCard('Killed', _killed(ledger, window, null)),
    ];
  }
  final picture = switch (species) {
    Species.pig => pigPopulation(animals, window.end),
    Species.cattle => cattleHerd(animals),
    _ => speciesPicture(animals, species),
  };
  return [
    _countCard('On farm', onFarm.length),
    HerdCard(
      title: species.plural,
      detail: onFarm.isEmpty
          ? 'None on the farm'
          : '${onFarm.length} on the farm',
      slices: picture,
    ),
    if (species == Species.cattle)
      HerdCard(title: 'Milk', detail: _milk(ledger, window)),
    _countCard('Born', _born(ledger, window, species)),
    _countCard('Killed', _killed(ledger, window, species)),
  ];
}

HerdCard _countCard(String title, int count) {
  return HerdCard(title: title, detail: count <= 0 ? 'None' : '$count');
}

int _born(FarmLedger ledger, ChartWindow window, Species? species) {
  var total = 0;
  for (final row in ledger.births) {
    if (species != null && row.species != species) {
      continue;
    }
    if (window.contains(row.happenedOn)) {
      total += row.bornAlive;
    }
  }
  return total;
}

int _killed(FarmLedger ledger, ChartWindow window, Species? species) {
  var total = 0;
  for (final row in ledger.deaths) {
    if (species != null && row.species != species) {
      continue;
    }
    if (window.contains(row.happenedOn)) {
      total += 1;
    }
  }
  return total;
}

String _milk(FarmLedger ledger, ChartWindow window) {
  var litres = 0.0;
  for (final row in ledger.milk) {
    if (window.contains(row.happenedOn)) {
      litres += row.litres;
    }
  }
  if (litres <= 0) {
    return 'None';
  }
  return formatLitres(litres);
}

/// Events from today, or from the past seven days including today.
List<HomeEvent> recentFarmEvents({
  required FarmLedger ledger,
  required DateTime today,
  required bool thisWeek,
  required bool showMoney,
  List<FarmEntry> book = const [],
}) {
  final end = DateTime(today.year, today.month, today.day);
  final start = thisWeek ? end.subtract(const Duration(days: 6)) : end;
  final range = ChartWindow(start: start, end: end);
  final events = <HomeEvent>[
    for (final row in ledger.births)
      if (range.contains(row.happenedOn))
        HomeEvent(
          day: row.happenedOn,
          title: 'Birth',
          detail:
              '${row.damTag} · ${row.bornAlive} alive'
              '${row.stillborn > 0 ? ' · ${row.stillborn} stillborn' : ''}',
        ),
    for (final row in ledger.deaths)
      if (range.contains(row.happenedOn))
        HomeEvent(
          day: row.happenedOn,
          title: 'Death',
          detail: '${row.animalTag} · ${row.cause}',
        ),
    for (final row in ledger.feedUses)
      if (range.contains(row.happenedOn))
        HomeEvent(
          day: row.happenedOn,
          title: 'Feed',
          detail:
              '${row.species.plural} · ${row.quantityKg.round()} kg ${row.feedType}',
        ),
    for (final row in ledger.health)
      if (range.contains(row.happenedOn))
        HomeEvent(
          day: row.happenedOn,
          title: row.kind == HealthKind.vaccine ? 'Vaccine' : 'Sickness',
          detail: row.note.isEmpty
              ? row.animalTag
              : '${row.animalTag} · ${row.note}',
        ),
    for (final row in ledger.weights)
      if (range.contains(row.weighedOn))
        HomeEvent(
          day: row.weighedOn,
          title: 'Weight',
          detail: '${row.animalTag} · ${row.weightKg.round()} kg',
        ),
    for (final row in ledger.milk)
      if (range.contains(row.happenedOn))
        HomeEvent(
          day: row.happenedOn,
          title: 'Milk',
          detail: '${row.cowTag} · ${formatLitres(row.litres)}',
        ),
    if (showMoney) ...[
      for (final row in ledger.sales)
        if (range.contains(row.happenedOn))
          HomeEvent(
            day: row.happenedOn,
            title: 'Sale',
            detail: '${row.enterprise.label} · ${formatCedis(row.amountCedis)}',
          ),
      for (final row in ledger.expenses)
        if (range.contains(row.happenedOn))
          HomeEvent(
            day: row.happenedOn,
            title: 'Expense',
            detail: '${row.itemLabel} · ${formatCedis(row.amountCedis)}',
          ),
    ],
  ];
  final recorded = events.length;
  for (final entry in book) {
    if (!range.contains(entry.happenedOn)) {
      continue;
    }
    if (!showMoney && entry.kind == BookKind.sale) {
      continue;
    }
    final event = HomeEvent(
      day: entry.happenedOn,
      title: _bookTitle(entry.kind),
      detail: _bookDetail(entry),
    );
    if (_alreadyListed(events.sublist(0, recorded), event)) {
      continue;
    }
    events.add(event);
  }
  events.sort((a, b) {
    final byDay = b.day.compareTo(a.day);
    if (byDay != 0) {
      return byDay;
    }
    return a.title.compareTo(b.title);
  });
  return events;
}

bool _alreadyListed(List<HomeEvent> events, HomeEvent candidate) {
  final day = DateTime(
    candidate.day.year,
    candidate.day.month,
    candidate.day.day,
  );
  final tag = candidate.detail.split('·').first.trim();
  for (final event in events) {
    final other = DateTime(event.day.year, event.day.month, event.day.day);
    if (other != day) {
      continue;
    }
    if (event.title == candidate.title) {
      return true;
    }
    if (candidate.title == 'Breeding' &&
        event.title == 'Birth' &&
        tag.isNotEmpty &&
        event.detail.contains(tag)) {
      return true;
    }
  }
  return false;
}

String _bookTitle(BookKind kind) {
  return switch (kind) {
    BookKind.sale => 'Sale',
    BookKind.death => 'Death',
    BookKind.feed => 'Feed',
    BookKind.health => 'Health',
    BookKind.milk => 'Milk',
    BookKind.breeding => 'Breeding',
  };
}

String _bookDetail(FarmEntry entry) {
  final tag = (entry.animalTag ?? '').trim();
  final note = entry.note.trim();
  final amount = switch (entry.kind) {
    BookKind.sale => entry.amount == null ? '' : formatCedis(entry.amount!),
    BookKind.milk => entry.amount == null ? '' : formatLitres(entry.amount!),
    _ => '',
  };
  return [
    if (tag.isNotEmpty) tag,
    if (amount.isNotEmpty) amount,
    if (note.isNotEmpty) note,
  ].join(' · ');
}

bool _tagSpecies(List<Animal> animals, String tag, Species species) {
  final wanted = tag.trim().toLowerCase();
  for (final animal in animals) {
    if (animal.tag.trim().toLowerCase() == wanted) {
      return animal.species == species;
    }
  }
  return false;
}

List<MoneyBucket> _days(FarmLedger ledger, DateTime start, DateTime end) {
  final buckets = <MoneyBucket>[];
  var day = start;
  while (!day.isAfter(end)) {
    buckets.add(_span(_weekdays[day.weekday - 1], ledger, day, day));
    day = day.add(const Duration(days: 1));
  }
  return buckets;
}

List<MoneyBucket> _weeks(FarmLedger ledger, DateTime start, DateTime end) {
  final buckets = <MoneyBucket>[];
  var cursor = start;
  while (!cursor.isAfter(end)) {
    var chunkEnd = cursor.add(const Duration(days: 6));
    if (chunkEnd.isAfter(end)) {
      chunkEnd = end;
    }
    buckets.add(
      _span('${cursor.day}–${chunkEnd.day}', ledger, cursor, chunkEnd),
    );
    cursor = chunkEnd.add(const Duration(days: 1));
  }
  return buckets;
}

List<MoneyBucket> _months(FarmLedger ledger, DateTime start, DateTime end) {
  final buckets = <MoneyBucket>[];
  var cursor = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);
  while (!cursor.isAfter(last)) {
    final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
    final from = cursor.isBefore(start) ? start : cursor;
    final to = monthEnd.isAfter(end) ? end : monthEnd;
    buckets.add(_span(_monthNames[cursor.month - 1], ledger, from, to));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return buckets;
}

MoneyBucket _span(String label, FarmLedger ledger, DateTime from, DateTime to) {
  var sales = 0.0;
  for (final sale in ledger.sales) {
    if (_inRange(sale.happenedOn, from, to)) {
      sales += sale.amountCedis;
    }
  }
  var expenses = 0.0;
  for (final expense in ledger.expenses) {
    if (_inRange(expense.happenedOn, from, to)) {
      expenses += expense.amountCedis;
    }
  }
  return MoneyBucket(label: label, sales: sales, expenses: expenses);
}

/// One label on a dual-line chart, such as piglets born and weaned.
class DualPoint {
  const DualPoint(this.label, this.left, this.right);

  final String label;
  final double left;
  final double right;
}

/// Parts stacked in one bar.
class StackMonth {
  const StackMonth(this.label, this.parts);

  final String label;
  final List<ChartSlice> parts;
}

/// Inclusive slices that match the sales chart buckets.
class TimeSlice {
  const TimeSlice({
    required this.label,
    required this.start,
    required this.end,
  });

  final String label;
  final DateTime start;
  final DateTime end;

  bool contains(DateTime day) {
    return ChartWindow(start: start, end: end).contains(day);
  }
}

List<TimeSlice> timeSlices(ChartWindow window) {
  final start = DateTime(
    window.start.year,
    window.start.month,
    window.start.day,
  );
  final end = DateTime(window.end.year, window.end.month, window.end.day);
  final days = end.difference(start).inDays;
  if (days <= 0) {
    return [TimeSlice(label: 'Today', start: start, end: end)];
  }
  if (days <= 16) {
    final slices = <TimeSlice>[];
    var day = start;
    while (!day.isAfter(end)) {
      slices.add(
        TimeSlice(label: _weekdays[day.weekday - 1], start: day, end: day),
      );
      day = day.add(const Duration(days: 1));
    }
    return slices;
  }
  if (days <= 62) {
    final slices = <TimeSlice>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      var chunkEnd = cursor.add(const Duration(days: 6));
      if (chunkEnd.isAfter(end)) {
        chunkEnd = end;
      }
      slices.add(
        TimeSlice(
          label: '${cursor.day}–${chunkEnd.day}',
          start: cursor,
          end: chunkEnd,
        ),
      );
      cursor = chunkEnd.add(const Duration(days: 1));
    }
    return slices;
  }
  final slices = <TimeSlice>[];
  var cursor = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);
  while (!cursor.isAfter(last)) {
    final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
    final from = cursor.isBefore(start) ? start : cursor;
    final to = monthEnd.isAfter(end) ? end : monthEnd;
    slices.add(
      TimeSlice(label: _monthNames[cursor.month - 1], start: from, end: to),
    );
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return slices;
}

/// Sows, boars, growers, and piglets still on the farm.
List<ChartSlice> pigPopulation(List<Animal> animals, DateTime today) {
  final cutoff = DateTime(
    today.year,
    today.month,
    today.day,
  ).subtract(const Duration(days: 56));
  var sows = 0;
  var boars = 0;
  var growers = 0;
  var piglets = 0;
  for (final animal in animals) {
    if (animal.species != Species.pig || animal.status != AnimalStatus.onFarm) {
      continue;
    }
    final klass = pigClassOf(animal);
    final born = animal.dateOfBirth;
    if (klass == PigClass.grower && born != null && !born.isBefore(cutoff)) {
      piglets += 1;
      continue;
    }
    switch (klass) {
      case PigClass.sow:
        sows += 1;
      case PigClass.boar:
        boars += 1;
      case PigClass.grower:
        growers += 1;
    }
  }
  return [
    if (sows > 0) ChartSlice('Sows', sows.toDouble()),
    if (boars > 0) ChartSlice('Boars', boars.toDouble()),
    if (growers > 0) ChartSlice('Growers', growers.toDouble()),
    if (piglets > 0) ChartSlice('Piglets', piglets.toDouble()),
  ];
}

/// Bulls, cows, and dairy cows still on the farm.
List<ChartSlice> cattleHerd(List<Animal> animals) {
  var bulls = 0;
  var cows = 0;
  var dairy = 0;
  for (final animal in animals) {
    if (animal.species != Species.cattle ||
        animal.status != AnimalStatus.onFarm) {
      continue;
    }
    if (animal.dairy) {
      dairy += 1;
    } else if (animal.sex == Sex.male) {
      bulls += 1;
    } else {
      cows += 1;
    }
  }
  return [
    if (bulls > 0) ChartSlice('Bulls', bulls.toDouble()),
    if (cows > 0) ChartSlice('Cows', cows.toDouble()),
    if (dairy > 0) ChartSlice('Dairy', dairy.toDouble()),
  ];
}

/// Piglets born alive and piglets weaned in each slice of the window.
List<DualPoint> litterSeries(FarmLedger ledger, ChartWindow window) {
  final points = <DualPoint>[];
  for (final slice in timeSlices(window)) {
    var born = 0.0;
    for (final row in ledger.births) {
      if (row.species == Species.pig && slice.contains(row.happenedOn)) {
        born += row.bornAlive;
      }
    }
    var weaned = 0.0;
    for (final row in ledger.breeding) {
      if (row.species != Species.pig || row.weaned == null) {
        continue;
      }
      final day = row.actualOn ?? row.servedOn;
      if (slice.contains(day)) {
        weaned += row.weaned!;
      }
    }
    if (born > 0 || weaned > 0) {
      points.add(DualPoint(slice.label, born, weaned));
    }
  }
  return points;
}

/// Litres of milk in each slice of the window.
List<ChartSlice> milkSeries(FarmLedger ledger, ChartWindow window) {
  final points = <ChartSlice>[];
  for (final slice in timeSlices(window)) {
    var litres = 0.0;
    for (final row in ledger.milk) {
      if (slice.contains(row.happenedOn)) {
        litres += row.litres;
      }
    }
    if (litres > 0) {
      points.add(ChartSlice(slice.label, litres));
    }
  }
  return points;
}

/// Deaths in each slice, split by species.
List<StackMonth> deathStacks(FarmLedger ledger, ChartWindow window) {
  final months = <StackMonth>[];
  for (final slice in timeSlices(window)) {
    final totals = {for (final species in Species.values) species: 0.0};
    for (final death in ledger.deaths) {
      if (!slice.contains(death.happenedOn)) {
        continue;
      }
      totals[death.species] = (totals[death.species] ?? 0) + 1;
    }
    final parts = [
      for (final species in Species.values)
        if ((totals[species] ?? 0) > 0)
          ChartSlice(species.plural, totals[species]!),
    ];
    if (parts.isNotEmpty) {
      months.add(StackMonth(slice.label, parts));
    }
  }
  return months;
}

/// Sales minus the feed cost carried by that enterprise.
List<ChartSlice> profitByEnterprise(FarmLedger ledger, ChartWindow window) {
  final revenue = {for (final enterprise in Enterprise.values) enterprise: 0.0};
  for (final sale in ledger.sales) {
    if (!window.contains(sale.happenedOn)) {
      continue;
    }
    revenue[sale.enterprise] =
        (revenue[sale.enterprise] ?? 0) + sale.amountCedis;
  }
  var feedCost = 0.0;
  for (final purchase in ledger.purchases) {
    if (window.contains(purchase.happenedOn)) {
      feedCost += purchase.costCedis;
    }
  }
  for (final expense in ledger.expenses) {
    if (window.contains(expense.happenedOn) &&
        expense.category == ExpenseCategory.feed) {
      feedCost += expense.amountCedis;
    }
  }
  final kilograms = {for (final species in Species.values) species: 0.0};
  var totalKg = 0.0;
  for (final use in ledger.feedUses) {
    if (!window.contains(use.happenedOn)) {
      continue;
    }
    kilograms[use.species] = (kilograms[use.species] ?? 0) + use.quantityKg;
    totalKg += use.quantityKg;
  }
  final cattle =
      (revenue[Enterprise.dairy] ?? 0) > (revenue[Enterprise.beef] ?? 0)
      ? Enterprise.dairy
      : Enterprise.beef;
  final slices = <ChartSlice>[];
  for (final enterprise in Enterprise.values) {
    if ((revenue[enterprise] ?? 0) <= 0) {
      continue;
    }
    final shareKg = switch (enterprise) {
      Enterprise.pig => kilograms[Species.pig] ?? 0,
      Enterprise.poultry => kilograms[Species.poultry] ?? 0,
      Enterprise.goat =>
        (kilograms[Species.goat] ?? 0) + (kilograms[Species.sheep] ?? 0),
      Enterprise.beef =>
        cattle == Enterprise.beef ? kilograms[Species.cattle] ?? 0 : 0,
      Enterprise.dairy =>
        cattle == Enterprise.dairy ? kilograms[Species.cattle] ?? 0 : 0,
      Enterprise.general => 0,
    };
    final share = totalKg == 0 ? 0.0 : shareKg / totalKg;
    slices.add(
      ChartSlice(
        enterprise.label,
        (revenue[enterprise] ?? 0) - feedCost * share,
      ),
    );
  }
  return slices;
}

/// Kilos mixed in each slice of the window.
List<ChartSlice> feedProduced(FeedMill mill, ChartWindow window) {
  final points = <ChartSlice>[];
  for (final slice in timeSlices(window)) {
    var kilograms = 0.0;
    for (final batch in mill.batches) {
      if (slice.contains(batch.producedOn)) {
        kilograms += batch.quantityKg;
      }
    }
    if (kilograms > 0) {
      points.add(ChartSlice(slice.label, kilograms));
    }
  }
  return points;
}

/// Feed given out, stacked by animal group.
List<StackMonth> feedIssuedStacks(FeedMill mill, ChartWindow window) {
  final months = <StackMonth>[];
  for (final slice in timeSlices(window)) {
    final totals = <String, double>{};
    for (final issue in mill.issues) {
      if (!slice.contains(issue.issuedOn)) {
        continue;
      }
      final label = issue.group.trim().isEmpty
          ? issue.species.plural
          : issue.group.trim();
      totals[label] = (totals[label] ?? 0) + issue.quantityKg;
    }
    if (totals.isEmpty) {
      continue;
    }
    final names = totals.keys.toList()..sort();
    months.add(
      StackMonth(slice.label, [
        for (final name in names) ChartSlice(name, totals[name]!),
      ]),
    );
  }
  return months;
}

bool _inRange(DateTime value, DateTime from, DateTime to) {
  final date = DateTime(value.year, value.month, value.day);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return !date.isBefore(start) && !date.isAfter(end);
}
