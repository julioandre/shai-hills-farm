import 'package:shai_hills_farm/domain/ledger.dart';

/// Feed still on hand: kilos bought minus kilos used.
class FeedBin {
  const FeedBin({
    required this.feedType,
    required this.boughtKg,
    required this.usedKg,
  });

  final String feedType;
  final double boughtKg;
  final double usedKg;

  double get onHandKg => boughtKg - usedKg;

  /// More was written as used than has been bought.
  bool get short => onHandKg < 0;
}

List<FeedBin> feedBins(FarmLedger ledger) {
  final bought = <String, double>{};
  final used = <String, double>{};
  for (final row in ledger.purchases) {
    final name = row.feedType.trim().isEmpty ? 'Feed' : row.feedType.trim();
    bought[name] = (bought[name] ?? 0) + row.quantityKg;
  }
  for (final row in ledger.expenses) {
    if (row.category != ExpenseCategory.feed || row.quantityKg == null) {
      continue;
    }
    final name = (row.feedType ?? 'Feed').trim();
    bought[name.isEmpty ? 'Feed' : name] =
        (bought[name.isEmpty ? 'Feed' : name] ?? 0) + row.quantityKg!;
  }
  for (final row in ledger.feedUses) {
    final name = row.feedType.trim().isEmpty ? 'Feed' : row.feedType.trim();
    used[name] = (used[name] ?? 0) + row.quantityKg;
  }
  final names = {...bought.keys, ...used.keys}.toList()..sort();
  return [
    for (final name in names)
      FeedBin(
        feedType: name,
        boughtKg: bought[name] ?? 0,
        usedKg: used[name] ?? 0,
      ),
  ];
}
