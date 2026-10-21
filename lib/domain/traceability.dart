import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

enum FarmPeriod { today, week, month, quarter, year }

/// True when [day] falls in [period] ending on [today].
bool inFarmPeriod(DateTime day, DateTime today, FarmPeriod period) {
  final date = DateTime(day.year, day.month, day.day);
  final end = DateTime(today.year, today.month, today.day);
  if (date.isAfter(end)) {
    return false;
  }
  return switch (period) {
    FarmPeriod.today => date == end,
    FarmPeriod.week => !date.isBefore(
      end.subtract(Duration(days: end.weekday - 1)),
    ),
    FarmPeriod.month => date.year == end.year && date.month == end.month,
    FarmPeriod.quarter =>
      date.year == end.year &&
          ((date.month - 1) ~/ 3) == ((end.month - 1) ~/ 3),
    FarmPeriod.year => date.year == end.year,
  };
}

double? pricePerKg(double? price, double? weightKg) {
  if (price == null || weightKg == null || weightKg <= 0) {
    return null;
  }
  return price / weightKg;
}

/// Sale price minus what was paid to bring the animal in.
double? profitEstimate(Animal animal) {
  final price = animal.salePrice;
  if (price == null) {
    return null;
  }
  return price - (animal.purchasePrice ?? 0) - (animal.transportCost ?? 0);
}

/// Carcass weight divided by live weight.
double? dressingPercent(double? carcassKg, double? liveKg) {
  if (carcassKg == null || liveKg == null || liveKg <= 0) {
    return null;
  }
  return carcassKg / liveKg * 100;
}

String? traceProblem(Animal animal, List<Animal> herd) {
  final origin = switch (animal.origin) {
    OriginType.born => _bornProblem(animal, herd),
    OriginType.purchased => _purchasedProblem(animal),
  };
  if (origin != null) {
    return origin;
  }
  return _exitProblem(animal);
}

String? _bornProblem(Animal animal, List<Animal> herd) {
  final mother = animal.motherTag?.trim() ?? '';
  final father = animal.fatherTag?.trim() ?? '';
  if (mother.isEmpty) {
    return 'Enter the mother tag.';
  }
  if (father.isEmpty) {
    return 'Enter the father tag.';
  }
  if (animal.dateOfBirth == null) {
    return 'Enter the birth date.';
  }
  if (animal.birthWeightKg != null && animal.birthWeightKg! <= 0) {
    return 'Enter the birth weight.';
  }
  if ((animal.birthLocationId ?? '').trim().isEmpty) {
    return 'Choose where it was born.';
  }
  if (_match(herd, mother, exceptId: animal.id) == null) {
    return 'Mother $mother is not on the register.';
  }
  if (_match(herd, father, exceptId: animal.id) == null) {
    return 'Father $father is not on the register.';
  }
  return null;
}

String? _purchasedProblem(Animal animal) {
  if ((animal.sourceFarm ?? '').trim().isEmpty) {
    return 'Enter the source farm.';
  }
  if ((animal.supplierName ?? '').trim().isEmpty) {
    return 'Enter the supplier.';
  }
  if (animal.purchaseDate == null) {
    return 'Enter the purchase date.';
  }
  if (animal.purchaseWeightKg == null || animal.purchaseWeightKg! <= 0) {
    return 'Enter the purchase weight.';
  }
  if (animal.purchasePrice == null || animal.purchasePrice! <= 0) {
    return 'Enter the purchase price.';
  }
  if (animal.transportCost == null || animal.transportCost! < 0) {
    return 'Enter the transport cost.';
  }
  if ((animal.breed ?? '').trim().isEmpty) {
    return 'Choose a breed.';
  }
  if ((animal.locationId ?? '').trim().isEmpty) {
    return 'Choose the location.';
  }
  return null;
}

String? _exitProblem(Animal animal) {
  return switch (animal.status) {
    AnimalStatus.onFarm => null,
    AnimalStatus.sold => _soldProblem(animal),
    AnimalStatus.slaughtered => _slaughterProblem(animal),
    AnimalStatus.dead => _deathProblem(animal),
    AnimalStatus.culled => _cullProblem(animal),
  };
}

String? _soldProblem(Animal animal) {
  if (animal.saleDate == null) {
    return 'Enter the sale date.';
  }
  if (animal.saleWeightKg == null || animal.saleWeightKg! <= 0) {
    return 'Enter the sale weight.';
  }
  if (animal.salePrice == null || animal.salePrice! <= 0) {
    return 'Enter the sale price.';
  }
  if ((animal.buyerName ?? '').trim().isEmpty) {
    return 'Enter the buyer.';
  }
  if ((animal.buyerContact ?? '').trim().isEmpty) {
    return 'Enter the buyer contact.';
  }
  return null;
}

String? _slaughterProblem(Animal animal) {
  if (animal.slaughterDate == null) {
    return 'Enter the slaughter date.';
  }
  if (animal.liveWeightKg == null || animal.liveWeightKg! <= 0) {
    return 'Enter the live weight.';
  }
  if (animal.carcassWeightKg == null || animal.carcassWeightKg! <= 0) {
    return 'Enter the carcass weight.';
  }
  if (animal.carcassWeightKg! > animal.liveWeightKg!) {
    return 'Carcass weight cannot be more than the live weight.';
  }
  if ((animal.slaughterDestination ?? '').trim().isEmpty) {
    return 'Enter where the meat went.';
  }
  return null;
}

String? _deathProblem(Animal animal) {
  if (animal.deathDate == null) {
    return 'Enter the date of death.';
  }
  if (animal.deathWeightKg == null || animal.deathWeightKg! <= 0) {
    return 'Enter the weight at death.';
  }
  if ((animal.deathCause ?? '').trim().isEmpty) {
    return 'Choose the cause of death.';
  }
  return null;
}

String? _cullProblem(Animal animal) {
  if (animal.cullDate == null) {
    return 'Enter the cull date.';
  }
  if (animal.cullWeightKg == null || animal.cullWeightKg! <= 0) {
    return 'Enter the weight.';
  }
  if (animal.cullReason == null) {
    return 'Choose why it was culled.';
  }
  return null;
}

Animal? _match(List<Animal> herd, String tag, {required String exceptId}) {
  final wanted = tag.trim().toLowerCase();
  for (final animal in herd) {
    if (animal.id != exceptId && animal.tag.toLowerCase() == wanted) {
      return animal;
    }
  }
  return null;
}

class LifeEvent {
  const LifeEvent({required this.day, required this.title, this.detail = ''});

  final DateTime day;
  final String title;
  final String detail;
}

/// Birth or purchase through to the way the animal left, plus book events.
List<LifeEvent> lifeHistory(Animal animal, FarmLedger ledger) {
  final events = <LifeEvent>[];
  if (animal.origin == OriginType.born && animal.dateOfBirth != null) {
    events.add(
      LifeEvent(
        day: animal.dateOfBirth!,
        title: 'Born on farm',
        detail: animal.birthWeightKg == null
            ? ''
            : '${animal.birthWeightKg!.round()} kg',
      ),
    );
  }
  if (animal.origin == OriginType.purchased && animal.purchaseDate != null) {
    events.add(
      LifeEvent(
        day: animal.purchaseDate!,
        title: 'Purchased',
        detail: animal.sourceFarm ?? '',
      ),
    );
  }
  final tag = animal.tag.toLowerCase();
  bool same(String? other) => (other ?? '').trim().toLowerCase() == tag;
  for (final row in ledger.weights) {
    if (same(row.animalTag)) {
      events.add(
        LifeEvent(
          day: row.weighedOn,
          title: 'Weight recorded',
          detail: '${row.weightKg.round()} kg',
        ),
      );
    }
  }
  for (final row in ledger.health) {
    if (same(row.animalTag)) {
      events.add(
        LifeEvent(
          day: row.happenedOn,
          title: row.kind == HealthKind.treatment ? 'Sickness' : row.kind.label,
          detail: row.note,
        ),
      );
    }
  }
  for (final row in ledger.breeding) {
    if (same(row.damTag) || same(row.sireTag)) {
      events.add(
        LifeEvent(
          day: row.servedOn,
          title: 'Breeding',
          detail: row.serviceKind.label,
        ),
      );
    }
  }
  for (final row in ledger.births) {
    if (same(row.damTag)) {
      events.add(
        LifeEvent(
          day: row.happenedOn,
          title: animal.species == Species.pig ? 'Farrowing' : 'Calving',
          detail: '${row.bornAlive} alive',
        ),
      );
    }
  }
  for (final row in ledger.milk) {
    if (same(row.cowTag)) {
      events.add(
        LifeEvent(
          day: row.happenedOn,
          title: 'Milk',
          detail: formatLitres(row.litres),
        ),
      );
    }
  }
  for (final row in ledger.deaths) {
    if (same(row.animalTag)) {
      events.add(
        LifeEvent(day: row.happenedOn, title: 'Death', detail: row.cause),
      );
    }
  }
  if (animal.status == AnimalStatus.sold && animal.saleDate != null) {
    events.add(
      LifeEvent(
        day: animal.saleDate!,
        title: 'Sold',
        detail: animal.buyerName ?? '',
      ),
    );
  }
  if (animal.status == AnimalStatus.slaughtered &&
      animal.slaughterDate != null) {
    events.add(
      LifeEvent(
        day: animal.slaughterDate!,
        title: 'Slaughtered',
        detail: animal.slaughterDestination ?? '',
      ),
    );
  }
  if (animal.status == AnimalStatus.dead && animal.deathDate != null) {
    events.add(
      LifeEvent(
        day: animal.deathDate!,
        title: 'Died',
        detail: animal.deathCause ?? '',
      ),
    );
  }
  if (animal.status == AnimalStatus.culled && animal.cullDate != null) {
    events.add(
      LifeEvent(
        day: animal.cullDate!,
        title: 'Culled',
        detail: animal.cullReason?.label ?? '',
      ),
    );
  }
  events.sort((a, b) => a.day.compareTo(b.day));
  return events;
}

class Kin {
  const Kin({required this.tag, this.mother, this.father});

  final String tag;
  final Kin? mother;
  final Kin? father;
}

/// Parents, grandparents, and further ancestors already on the register.
///
/// A parent that points back at itself is stopped, so a bad record cannot loop.
Kin ancestry(Animal animal, List<Animal> herd, {int depth = 8}) {
  Kin? parent(String? tag, int left, Set<String> seen) {
    final name = tag?.trim() ?? '';
    if (name.isEmpty || left < 0) {
      return null;
    }
    final key = name.toLowerCase();
    if (!seen.add(key)) {
      return Kin(tag: name);
    }
    final match = _match(herd, name, exceptId: animal.id);
    if (match == null || left == 0) {
      return Kin(tag: name);
    }
    return Kin(
      tag: match.tag,
      mother: parent(match.motherTag, left - 1, {...seen}),
      father: parent(match.fatherTag, left - 1, {...seen}),
    );
  }

  final start = {animal.tag.trim().toLowerCase()};
  return Kin(
    tag: animal.tag,
    mother: parent(animal.motherTag, depth - 1, {...start}),
    father: parent(animal.fatherTag, depth - 1, {...start}),
  );
}

/// Animals on the register whose mother or father is this animal.
List<Animal> offspring(Animal animal, List<Animal> herd) {
  final tag = animal.tag.trim().toLowerCase();
  if (tag.isEmpty) {
    return const [];
  }
  return [
    for (final other in herd)
      if (other.id != animal.id &&
          (_sameTag(other.motherTag, tag) || _sameTag(other.fatherTag, tag)))
        other,
  ];
}

bool _sameTag(String? tag, String wanted) {
  return (tag ?? '').trim().toLowerCase() == wanted;
}

class HerdSlice {
  const HerdSlice(this.label, this.count);

  final String label;
  final int count;
}

/// On-farm animals, with dairy cattle counted apart from beef cattle.
List<HerdSlice> herdComposition(Iterable<Animal> animals) {
  final counts = <String, int>{};
  for (final animal in animals) {
    if (animal.status != AnimalStatus.onFarm) {
      continue;
    }
    final label = animal.species == Species.cattle && animal.dairy
        ? 'Dairy'
        : animal.species.plural;
    counts[label] = (counts[label] ?? 0) + 1;
  }
  final slices = [
    for (final entry in counts.entries) HerdSlice(entry.key, entry.value),
  ]..sort((a, b) => b.count.compareTo(a.count));
  return slices;
}

class OriginSplit {
  const OriginSplit({required this.born, required this.purchased});

  final int born;
  final int purchased;
}

OriginSplit originSplit(Iterable<Animal> animals) {
  var born = 0;
  var purchased = 0;
  for (final animal in animals) {
    if (animal.status != AnimalStatus.onFarm) {
      continue;
    }
    if (animal.origin == OriginType.purchased) {
      purchased += 1;
    } else {
      born += 1;
    }
  }
  return OriginSplit(born: born, purchased: purchased);
}

class MonthOrigin {
  const MonthOrigin({
    required this.label,
    required this.born,
    required this.purchased,
  });

  final String label;
  final int born;
  final int purchased;
}

/// Born and purchased counts for each month that falls in [period].
List<MonthOrigin> originByMonth(
  Iterable<Animal> animals,
  DateTime today,
  FarmPeriod period,
) {
  final buckets = <DateTime, ({int born, int purchased})>{};
  void add(DateTime? day, {required bool purchased}) {
    if (day == null || !inFarmPeriod(day, today, period)) {
      return;
    }
    final key = DateTime(day.year, day.month);
    final current = buckets[key] ?? (born: 0, purchased: 0);
    buckets[key] = purchased
        ? (born: current.born, purchased: current.purchased + 1)
        : (born: current.born + 1, purchased: current.purchased);
  }

  for (final animal in animals) {
    if (animal.origin == OriginType.purchased) {
      add(animal.purchaseDate, purchased: true);
    } else {
      add(animal.dateOfBirth, purchased: false);
    }
  }
  final keys = buckets.keys.toList()..sort();
  return [
    for (final key in keys)
      MonthOrigin(
        label: formatFarmDate(key).split(' ').skip(1).join(' '),
        born: buckets[key]!.born,
        purchased: buckets[key]!.purchased,
      ),
  ];
}
