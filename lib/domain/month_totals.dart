import 'package:shai_hills_farm/domain/farm_entry.dart';

/// Milk, sales, and deaths written in the book during one calendar month.
class MonthTotals {
  const MonthTotals({
    required this.notes,
    required this.milkLitres,
    required this.salesCedis,
    required this.deaths,
  });

  static const empty = MonthTotals(
    notes: 0,
    milkLitres: 0,
    salesCedis: 0,
    deaths: 0,
  );

  final int notes;
  final double milkLitres;
  final double salesCedis;
  final int deaths;

  bool get isEmpty => notes == 0;

  factory MonthTotals.forMonth(Iterable<FarmEntry> entries, DateTime month) {
    var notes = 0;
    var milk = 0.0;
    var sales = 0.0;
    var deaths = 0;
    for (final entry in entries) {
      if (entry.happenedOn.year != month.year ||
          entry.happenedOn.month != month.month) {
        continue;
      }
      notes += 1;
      switch (entry.kind) {
        case BookKind.milk:
          milk += entry.amount ?? 0;
        case BookKind.sale:
          sales += entry.amount ?? 0;
        case BookKind.death:
          deaths += 1;
        case BookKind.health:
        case BookKind.feed:
        case BookKind.breeding:
          break;
      }
    }
    return MonthTotals(
      notes: notes,
      milkLitres: milk,
      salesCedis: sales,
      deaths: deaths,
    );
  }
}
