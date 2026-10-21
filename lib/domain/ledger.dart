import 'package:shai_hills_farm/domain/animal.dart';

/// A record is pending until the phone can send it to Supabase.
enum SyncState {
  pending('pending'),
  synced('synced');

  const SyncState(this.wire);

  final String wire;

  static SyncState parse(Object? value) {
    if (value == SyncState.synced.wire) {
      return SyncState.synced;
    }
    return SyncState.pending;
  }
}

enum ServiceKind {
  natural('natural', 'Natural service'),
  ai('ai', 'AI');

  const ServiceKind(this.wire, this.label);

  final String wire;
  final String label;

  static ServiceKind parse(String value) {
    for (final kind in ServiceKind.values) {
      if (kind.wire == value) {
        return kind;
      }
    }
    return ServiceKind.natural;
  }
}

enum PregnancyCheck {
  open('open', 'Open'),
  pregnant('pregnant', 'Pregnant');

  const PregnancyCheck(this.wire, this.label);

  final String wire;
  final String label;

  static PregnancyCheck? parse(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final check in PregnancyCheck.values) {
      if (check.wire == value) {
        return check;
      }
    }
    return null;
  }
}

enum HealthKind {
  treatment('treatment', 'Treatment'),
  deworm('deworm', 'Deworming'),
  vaccine('vaccine', 'Vaccine'),
  vet('vet', 'Vet visit');

  const HealthKind(this.wire, this.label);

  final String wire;
  final String label;

  static HealthKind parse(String value) {
    for (final kind in HealthKind.values) {
      if (kind.wire == value) {
        return kind;
      }
    }
    return HealthKind.treatment;
  }
}

enum SaleKind {
  livestock('livestock', 'Livestock'),
  poultry('poultry', 'Poultry'),
  milk('milk', 'Milk'),
  feed('feed', 'Feed'),
  breedingStock('breeding_stock', 'Breeding stock');

  const SaleKind(this.wire, this.label);

  final String wire;
  final String label;

  static SaleKind parse(String value) {
    for (final kind in SaleKind.values) {
      if (kind.wire == value) {
        return kind;
      }
    }
    return SaleKind.livestock;
  }
}

/// Pig, beef, dairy, and poultry are the enterprises the farm is growing.
enum Enterprise {
  pig('pig', 'Piggery'),
  beef('beef', 'Beef'),
  dairy('dairy', 'Dairy'),
  poultry('poultry', 'Poultry'),
  goat('goat', 'Goats'),
  general('general', 'Farm');

  const Enterprise(this.wire, this.label);

  final String wire;
  final String label;

  static Enterprise parse(String value) {
    for (final enterprise in Enterprise.values) {
      if (enterprise.wire == value) {
        return enterprise;
      }
    }
    throw FormatException('Unknown enterprise "$value".');
  }

  static Enterprise forSpecies(Species species) {
    return switch (species) {
      Species.pig => Enterprise.pig,
      Species.cattle => Enterprise.beef,
      Species.goat => Enterprise.goat,
      Species.sheep => Enterprise.goat,
      Species.poultry => Enterprise.poultry,
    };
  }
}

enum LandUse {
  pasture('pasture', 'Pasture'),
  maize('maize', 'Maize'),
  soybean('soybean', 'Soybean'),
  napier('napier', 'Napier grass'),
  fallow('fallow', 'Fallow');

  const LandUse(this.wire, this.label);

  final String wire;
  final String label;

  static LandUse parse(String value) {
    for (final use in LandUse.values) {
      if (use.wire == value) {
        return use;
      }
    }
    return LandUse.pasture;
  }
}

class BirthRecord {
  const BirthRecord({
    required this.id,
    required this.happenedOn,
    required this.species,
    required this.damTag,
    required this.bornAlive,
    required this.stillborn,
    required this.locationId,
    required this.updatedAt,
    this.sireTag,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final Species species;
  final String damTag;
  final String? sireTag;
  final int bornAlive;
  final int stillborn;
  final String locationId;
  final DateTime updatedAt;
  final SyncState sync;

  BirthRecord copyWith({SyncState? sync}) {
    return BirthRecord(
      id: id,
      happenedOn: happenedOn,
      species: species,
      damTag: damTag,
      sireTag: sireTag,
      bornAlive: bornAlive,
      stillborn: stillborn,
      locationId: locationId,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory BirthRecord.fromJson(Map<String, dynamic> json) {
    return BirthRecord(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      species: Species.parse(_string(json, 'species')),
      damTag: _string(json, 'damTag', alt: 'dam_tag'),
      sireTag: _optional(json['sireTag'] ?? json['sire_tag']),
      bornAlive: _int(json['bornAlive'] ?? json['born_alive']),
      stillborn: _int(json['stillborn'] ?? json['stillborn']),
      locationId: _string(json, 'locationId', alt: 'location_id'),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'species': species.wire,
      'damTag': damTag,
      'sireTag': sireTag,
      'bornAlive': bornAlive,
      'stillborn': stillborn,
      'locationId': locationId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'species': species.wire,
      'dam_tag': damTag,
      'sire_tag': sireTag,
      'born_alive': bornAlive,
      'stillborn': stillborn,
      'location_id': locationId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class DeathRecord {
  const DeathRecord({
    required this.id,
    required this.happenedOn,
    required this.animalTag,
    required this.species,
    required this.cause,
    required this.locationId,
    required this.updatedAt,
    this.ageDays,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final String animalTag;
  final Species species;
  final String cause;
  final String locationId;
  final int? ageDays;
  final DateTime updatedAt;
  final SyncState sync;

  DeathRecord copyWith({SyncState? sync}) {
    return DeathRecord(
      id: id,
      happenedOn: happenedOn,
      animalTag: animalTag,
      species: species,
      cause: cause,
      locationId: locationId,
      ageDays: ageDays,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory DeathRecord.fromJson(Map<String, dynamic> json) {
    return DeathRecord(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      animalTag: _string(json, 'animalTag', alt: 'animal_tag'),
      species: Species.parse(_string(json, 'species')),
      cause: _string(json, 'cause'),
      locationId: _string(json, 'locationId', alt: 'location_id'),
      ageDays: _optionalInt(json['ageDays'] ?? json['age_days']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'animalTag': animalTag,
      'species': species.wire,
      'cause': cause,
      'locationId': locationId,
      'ageDays': ageDays,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'animal_tag': animalTag,
      'species': species.wire,
      'cause': cause,
      'location_id': locationId,
      'age_days': ageDays,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class FeedUse {
  const FeedUse({
    required this.id,
    required this.happenedOn,
    required this.locationId,
    required this.species,
    required this.feedType,
    required this.quantityKg,
    required this.updatedAt,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final String locationId;
  final Species species;
  final String feedType;
  final double quantityKg;
  final DateTime updatedAt;
  final SyncState sync;

  FeedUse copyWith({SyncState? sync}) {
    return FeedUse(
      id: id,
      happenedOn: happenedOn,
      locationId: locationId,
      species: species,
      feedType: feedType,
      quantityKg: quantityKg,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory FeedUse.fromJson(Map<String, dynamic> json) {
    return FeedUse(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      locationId: _string(json, 'locationId', alt: 'location_id'),
      species: Species.parse(_string(json, 'species')),
      feedType: _string(json, 'feedType', alt: 'feed_type'),
      quantityKg: _double(json['quantityKg'] ?? json['quantity_kg']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'locationId': locationId,
      'species': species.wire,
      'feedType': feedType,
      'quantityKg': quantityKg,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'location_id': locationId,
      'species': species.wire,
      'feed_type': feedType,
      'quantity_kg': quantityKg,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class FeedPurchase {
  const FeedPurchase({
    required this.id,
    required this.happenedOn,
    required this.supplier,
    required this.feedType,
    required this.costCedis,
    required this.quantityKg,
    required this.locationId,
    required this.updatedAt,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final String supplier;
  final String feedType;
  final double costCedis;
  final double quantityKg;
  final String locationId;
  final DateTime updatedAt;
  final SyncState sync;

  FeedPurchase copyWith({SyncState? sync}) {
    return FeedPurchase(
      id: id,
      happenedOn: happenedOn,
      supplier: supplier,
      feedType: feedType,
      costCedis: costCedis,
      quantityKg: quantityKg,
      locationId: locationId,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory FeedPurchase.fromJson(Map<String, dynamic> json) {
    return FeedPurchase(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      supplier: _string(json, 'supplier'),
      feedType: _string(json, 'feedType', alt: 'feed_type'),
      costCedis: _double(json['costCedis'] ?? json['cost_cedis']),
      quantityKg: _double(json['quantityKg'] ?? json['quantity_kg']),
      locationId: _string(json, 'locationId', alt: 'location_id'),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'supplier': supplier,
      'feedType': feedType,
      'costCedis': costCedis,
      'quantityKg': quantityKg,
      'locationId': locationId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'supplier': supplier,
      'feed_type': feedType,
      'cost_cedis': costCedis,
      'quantity_kg': quantityKg,
      'location_id': locationId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class BreedingService {
  const BreedingService({
    required this.id,
    required this.species,
    required this.damTag,
    required this.serviceKind,
    required this.servedOn,
    required this.expectedOn,
    required this.updatedAt,
    this.sireTag,
    this.heatOn,
    this.actualOn,
    this.bornAlive,
    this.stillborn,
    this.weaned,
    this.pregnancy,
    this.breed,
    this.sync = SyncState.pending,
  });

  final String id;
  final Species species;
  final String damTag;
  final String? sireTag;
  final ServiceKind serviceKind;
  final DateTime? heatOn;
  final DateTime servedOn;
  final DateTime expectedOn;
  final DateTime? actualOn;
  final int? bornAlive;
  final int? stillborn;
  final int? weaned;
  final PregnancyCheck? pregnancy;
  final String? breed;
  final DateTime updatedAt;
  final SyncState sync;

  BreedingService copyWith({SyncState? sync}) {
    return BreedingService(
      id: id,
      species: species,
      damTag: damTag,
      sireTag: sireTag,
      serviceKind: serviceKind,
      heatOn: heatOn,
      servedOn: servedOn,
      expectedOn: expectedOn,
      actualOn: actualOn,
      bornAlive: bornAlive,
      stillborn: stillborn,
      weaned: weaned,
      pregnancy: pregnancy,
      breed: breed,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory BreedingService.fromJson(Map<String, dynamic> json) {
    return BreedingService(
      id: _string(json, 'id'),
      species: Species.parse(_string(json, 'species')),
      damTag: _string(json, 'damTag', alt: 'dam_tag'),
      sireTag: _optional(json['sireTag'] ?? json['sire_tag']),
      serviceKind: ServiceKind.parse(
        _string(json, 'serviceKind', alt: 'service_kind'),
      ),
      heatOn: _optionalDate(json['heatOn'] ?? json['heat_on']),
      servedOn: _date(json['servedOn'] ?? json['served_on']),
      expectedOn: _date(json['expectedOn'] ?? json['expected_on']),
      actualOn: _optionalDate(json['actualOn'] ?? json['actual_on']),
      bornAlive: _optionalInt(json['bornAlive'] ?? json['born_alive']),
      stillborn: _optionalInt(json['stillborn']),
      weaned: _optionalInt(json['weaned']),
      pregnancy: PregnancyCheck.parse(json['pregnancy']),
      breed: _optional(json['breed']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'species': species.wire,
      'damTag': damTag,
      'sireTag': sireTag,
      'serviceKind': serviceKind.wire,
      'heatOn': heatOn == null ? null : formatLedgerDate(heatOn!),
      'servedOn': formatLedgerDate(servedOn),
      'expectedOn': formatLedgerDate(expectedOn),
      'actualOn': actualOn == null ? null : formatLedgerDate(actualOn!),
      'bornAlive': bornAlive,
      'stillborn': stillborn,
      'weaned': weaned,
      'pregnancy': pregnancy?.wire,
      'breed': breed,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'species': species.wire,
      'dam_tag': damTag,
      'sire_tag': sireTag,
      'service_kind': serviceKind.wire,
      'heat_on': heatOn == null ? null : formatLedgerDate(heatOn!),
      'served_on': formatLedgerDate(servedOn),
      'expected_on': formatLedgerDate(expectedOn),
      'actual_on': actualOn == null ? null : formatLedgerDate(actualOn!),
      'born_alive': bornAlive,
      'stillborn': stillborn,
      'weaned': weaned,
      'pregnancy': pregnancy?.wire,
      'breed': breed,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class WeightRecord {
  const WeightRecord({
    required this.id,
    required this.animalTag,
    required this.species,
    required this.weighedOn,
    required this.weightKg,
    required this.updatedAt,
    this.sync = SyncState.pending,
  });

  final String id;
  final String animalTag;
  final Species species;
  final DateTime weighedOn;
  final double weightKg;
  final DateTime updatedAt;
  final SyncState sync;

  WeightRecord copyWith({SyncState? sync}) {
    return WeightRecord(
      id: id,
      animalTag: animalTag,
      species: species,
      weighedOn: weighedOn,
      weightKg: weightKg,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: _string(json, 'id'),
      animalTag: _string(json, 'animalTag', alt: 'animal_tag'),
      species: Species.parse(_string(json, 'species')),
      weighedOn: _date(json['weighedOn'] ?? json['weighed_on']),
      weightKg: _double(json['weightKg'] ?? json['weight_kg']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'animalTag': animalTag,
      'species': species.wire,
      'weighedOn': formatLedgerDate(weighedOn),
      'weightKg': weightKg,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'animal_tag': animalTag,
      'species': species.wire,
      'weighed_on': formatLedgerDate(weighedOn),
      'weight_kg': weightKg,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class HealthEvent {
  const HealthEvent({
    required this.id,
    required this.animalTag,
    required this.kind,
    required this.happenedOn,
    required this.note,
    required this.updatedAt,
    this.nextDue,
    this.sync = SyncState.pending,
  });

  final String animalTag;
  final String id;
  final HealthKind kind;
  final DateTime happenedOn;
  final DateTime? nextDue;
  final String note;
  final DateTime updatedAt;
  final SyncState sync;

  HealthEvent copyWith({SyncState? sync}) {
    return HealthEvent(
      id: id,
      animalTag: animalTag,
      kind: kind,
      happenedOn: happenedOn,
      nextDue: nextDue,
      note: note,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory HealthEvent.fromJson(Map<String, dynamic> json) {
    return HealthEvent(
      id: _string(json, 'id'),
      animalTag: _string(json, 'animalTag', alt: 'animal_tag'),
      kind: HealthKind.parse(_string(json, 'kind')),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      nextDue: _optionalDate(json['nextDue'] ?? json['next_due']),
      note: _string(json, 'note'),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'animalTag': animalTag,
      'kind': kind.wire,
      'happenedOn': formatLedgerDate(happenedOn),
      'nextDue': nextDue == null ? null : formatLedgerDate(nextDue!),
      'note': note,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'animal_tag': animalTag,
      'kind': kind.wire,
      'happened_on': formatLedgerDate(happenedOn),
      'next_due': nextDue == null ? null : formatLedgerDate(nextDue!),
      'note': note,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

enum ExpenseCategory {
  feed('feed', 'Feed'),
  vet('vet', 'Vet'),
  labour('labour', 'Labour'),
  transport('transport', 'Transport'),
  fuel('fuel', 'Fuel'),
  repairs('repairs', 'Repairs'),
  other('other', 'Other');

  const ExpenseCategory(this.wire, this.label);

  final String wire;
  final String label;

  static ExpenseCategory parse(String value) {
    for (final category in ExpenseCategory.values) {
      if (category.wire == value) {
        return category;
      }
    }
    return ExpenseCategory.other;
  }
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.happenedOn,
    required this.category,
    required this.amountCedis,
    required this.locationId,
    required this.updatedAt,
    this.note = '',
    this.quantityKg,
    this.feedType,
    this.animalTag,
    this.people,
    this.days,
    this.litres,
    this.detail,
    this.supplier = '',
    this.hasReceipt = false,
    this.itemName = '',
    this.quantity,
    this.receiptId = '',
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final ExpenseCategory category;
  final double amountCedis;
  final String note;

  /// Kilos bought. Used when the category is feed.
  final double? quantityKg;
  final String? feedType;

  /// Tag the vet cost belongs to.
  final String? animalTag;

  /// People and days for a labour cost.
  final int? people;
  final double? days;

  /// Litres for a fuel cost.
  final double? litres;

  /// Where a trip went, or what was repaired.
  final String? detail;
  final String supplier;
  final bool hasReceipt;

  /// What was bought, in the words on the receipt.
  final String itemName;

  /// How many, for costs that are not feed. Feed uses kilos.
  final double? quantity;

  /// Lines saved from one shop receipt share this id. Empty on older rows.
  final String receiptId;
  final String locationId;
  final DateTime updatedAt;
  final SyncState sync;

  /// Category, and for feed, vet, and fuel the specific type as well.
  String get itemLabel {
    final specific = switch (category) {
      ExpenseCategory.feed => feedType?.trim() ?? '',
      ExpenseCategory.vet => _spentKind(detail, note, const {
        'deworm': 'Deworming',
        'vaccin': 'Vaccination',
        'iron': 'Treatment',
        'treat': 'Treatment',
        'visit': 'Visit',
      }),
      ExpenseCategory.fuel => _spentKind(detail, note, const {
        'petrol': 'Petrol',
        'diesel': 'Diesel',
        'gas': 'Gas',
      }),
      _ => '',
    };
    if (specific.isEmpty) {
      return category.label;
    }
    return '${category.label} · $specific';
  }

  /// One line for the expense list. Category first, then the extra facts.
  String get summary {
    final parts = <String>[];
    if (feedType != null) {
      parts.add(feedType!);
    }
    if (quantityKg != null && quantityKg! > 0) {
      parts.add('${_plainNumber(quantityKg!)} kg');
    }
    if (animalTag != null) {
      parts.add(animalTag!);
    }
    if (people != null && days != null) {
      parts.add('$people people, ${_plainNumber(days!)} days');
    }
    if (litres != null && litres! > 0) {
      parts.add('${_plainNumber(litres!)} L');
    }
    if (detail != null) {
      parts.add(detail!);
    }
    if (supplier.trim().isNotEmpty) {
      parts.add(supplier.trim());
    }
    if (hasReceipt) {
      parts.add('Receipt photo');
    }
    if (parts.isEmpty) {
      return category.label;
    }
    return '${category.label} · ${parts.join(' · ')}';
  }

  ExpenseRecord copyWith({SyncState? sync}) {
    return ExpenseRecord(
      id: id,
      happenedOn: happenedOn,
      category: category,
      amountCedis: amountCedis,
      note: note,
      quantityKg: quantityKg,
      feedType: feedType,
      animalTag: animalTag,
      people: people,
      days: days,
      litres: litres,
      detail: detail,
      supplier: supplier,
      hasReceipt: hasReceipt,
      itemName: itemName,
      quantity: quantity,
      receiptId: receiptId,
      locationId: locationId,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    return ExpenseRecord(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      category: ExpenseCategory.parse(_string(json, 'category')),
      amountCedis: _double(json['amountCedis'] ?? json['amount_cedis']),
      note: _optional(json['note']) ?? '',
      quantityKg: _optionalDouble(json['quantityKg'] ?? json['quantity_kg']),
      feedType: _optional(json['feedType'] ?? json['feed_type']),
      animalTag: _optional(json['animalTag'] ?? json['animal_tag']),
      people: _optionalInt(json['people']),
      days: _optionalDouble(json['days']),
      litres: _optionalDouble(json['litres']),
      detail: _optional(json['detail']),
      supplier: _optional(json['supplier']) ?? '',
      hasReceipt: json['hasReceipt'] == true || json['has_receipt'] == true,
      itemName: _optional(json['itemName'] ?? json['item_name']) ?? '',
      quantity: _optionalDouble(json['quantity']),
      receiptId: _optional(json['receiptId'] ?? json['receipt_id']) ?? '',
      locationId: _string(json, 'locationId', alt: 'location_id'),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'category': category.wire,
      'amountCedis': amountCedis,
      'note': note,
      'quantityKg': quantityKg,
      'feedType': feedType,
      'animalTag': animalTag,
      'people': people,
      'days': days,
      'litres': litres,
      'detail': detail,
      'supplier': supplier,
      'hasReceipt': hasReceipt,
      'itemName': itemName,
      'quantity': quantity,
      'receiptId': receiptId,
      'locationId': locationId,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'category': category.wire,
      'amount_cedis': amountCedis,
      'note': note,
      'quantity_kg': quantityKg,
      'feed_type': feedType,
      'animal_tag': animalTag,
      'people': people,
      'days': days,
      'litres': litres,
      'detail': detail,
      'supplier': supplier,
      'has_receipt': hasReceipt,
      'item_name': itemName,
      'quantity': quantity,
      'receipt_id': receiptId,
      'location_id': locationId,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

/// A vaccination bill is the cost of the medicine. The animal is recorded
/// on Record, so the expense does not need a tag.
bool _vetNeedsAnimal(String detail) {
  return detail.trim().toLowerCase() != 'vaccination';
}

/// What is still missing before this expense can be saved.
String? expenseProblem(ExpenseRecord record) {
  if (record.amountCedis <= 0) {
    return 'Enter the amount in cedis.';
  }
  final detail = switch (record.category) {
    ExpenseCategory.feed =>
      (record.quantityKg == null || record.quantityKg! <= 0)
          ? 'Enter the kilos.'
          : (record.feedType == null || record.feedType!.trim().isEmpty)
          ? 'Choose the feed.'
          : null,
    ExpenseCategory.vet =>
      (record.detail == null || record.detail!.trim().isEmpty)
          ? 'Choose what the vet cost was.'
          : _vetNeedsAnimal(record.detail!) &&
                (record.animalTag == null || record.animalTag!.trim().isEmpty)
          ? 'Enter the animal tag.'
          : null,
    ExpenseCategory.labour =>
      (record.people == null ||
              record.people! <= 0 ||
              record.days == null ||
              record.days! <= 0)
          ? 'Enter how many people and how many days.'
          : null,
    ExpenseCategory.transport =>
      (record.detail == null || record.detail!.trim().isEmpty)
          ? 'Enter where it went.'
          : null,
    ExpenseCategory.fuel =>
      (record.detail == null || record.detail!.trim().isEmpty)
          ? 'Choose the fuel.'
          : (record.litres == null || record.litres! <= 0)
          ? 'Enter the litres.'
          : null,
    ExpenseCategory.repairs =>
      (record.detail == null || record.detail!.trim().isEmpty)
          ? 'Enter what was repaired.'
          : null,
    ExpenseCategory.other =>
      record.note.trim().isEmpty ? 'Write what it was.' : null,
  };
  if (detail != null) {
    return detail;
  }
  if (record.itemName.trim().isEmpty) {
    return 'Name the item.';
  }
  if (record.category != ExpenseCategory.feed &&
      (record.quantity == null || record.quantity! <= 0)) {
    return 'Enter the quantity.';
  }
  return null;
}

String _spentKind(String? chosen, String note, Map<String, String> hints) {
  final picked = chosen?.trim() ?? '';
  if (picked.isNotEmpty) {
    return picked;
  }
  final lower = note.toLowerCase();
  for (final entry in hints.entries) {
    if (lower.contains(entry.key)) {
      return entry.value;
    }
  }
  return '';
}

String _plainNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class SaleRecord {
  const SaleRecord({
    required this.id,
    required this.happenedOn,
    required this.kind,
    required this.enterprise,
    required this.locationId,
    required this.amountCedis,
    required this.updatedAt,
    this.quantity,
    this.itemName = '',
    this.animalTag = '',
    this.weightKg,
    this.costCedis,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final SaleKind kind;
  final Enterprise enterprise;
  final String locationId;
  final double amountCedis;
  final double? quantity;

  /// What was sold.
  final String itemName;

  /// Tag of the animal, when this sale is one animal.
  final String animalTag;
  final double? weightKg;

  /// Extra cost of the sale, such as transport.
  final double? costCedis;
  final DateTime updatedAt;
  final SyncState sync;

  SaleRecord copyWith({SyncState? sync}) {
    return SaleRecord(
      id: id,
      happenedOn: happenedOn,
      kind: kind,
      enterprise: enterprise,
      locationId: locationId,
      amountCedis: amountCedis,
      quantity: quantity,
      itemName: itemName,
      animalTag: animalTag,
      weightKg: weightKg,
      costCedis: costCedis,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory SaleRecord.fromJson(Map<String, dynamic> json) {
    return SaleRecord(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      kind: SaleKind.parse(_string(json, 'kind')),
      enterprise: Enterprise.parse(_string(json, 'enterprise')),
      locationId: _string(json, 'locationId', alt: 'location_id'),
      amountCedis: _double(json['amountCedis'] ?? json['amount_cedis']),
      quantity: _optionalDouble(json['quantity']),
      itemName: _optional(json['itemName'] ?? json['item_name']) ?? '',
      animalTag: _optional(json['animalTag'] ?? json['animal_tag']) ?? '',
      weightKg: _optionalDouble(json['weightKg'] ?? json['weight_kg']),
      costCedis: _optionalDouble(json['costCedis'] ?? json['cost_cedis']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'kind': kind.wire,
      'enterprise': enterprise.wire,
      'locationId': locationId,
      'amountCedis': amountCedis,
      'quantity': quantity,
      'itemName': itemName,
      'animalTag': animalTag,
      'weightKg': weightKg,
      'costCedis': costCedis,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'kind': kind.wire,
      'enterprise': enterprise.wire,
      'location_id': locationId,
      'amount_cedis': amountCedis,
      'quantity': quantity,
      'item_name': itemName,
      'animal_tag': animalTag,
      'weight_kg': weightKg,
      'cost_cedis': costCedis,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class MilkYield {
  const MilkYield({
    required this.id,
    required this.happenedOn,
    required this.cowTag,
    required this.morningLitres,
    required this.eveningLitres,
    required this.updatedAt,
    this.sync = SyncState.pending,
  });

  final String id;
  final DateTime happenedOn;
  final String cowTag;
  final double morningLitres;
  final double eveningLitres;
  final DateTime updatedAt;
  final SyncState sync;

  double get litres => morningLitres + eveningLitres;

  MilkYield copyWith({SyncState? sync}) {
    return MilkYield(
      id: id,
      happenedOn: happenedOn,
      cowTag: cowTag,
      morningLitres: morningLitres,
      eveningLitres: eveningLitres,
      updatedAt: updatedAt,
      sync: sync ?? this.sync,
    );
  }

  factory MilkYield.fromJson(Map<String, dynamic> json) {
    return MilkYield(
      id: _string(json, 'id'),
      happenedOn: _date(json['happenedOn'] ?? json['happened_on']),
      cowTag: _string(json, 'cowTag', alt: 'cow_tag'),
      morningLitres: _double(json['morningLitres'] ?? json['morning_litres']),
      eveningLitres: _double(json['eveningLitres'] ?? json['evening_litres']),
      updatedAt: _time(json['updatedAt'] ?? json['updated_at']),
      sync: SyncState.parse(json['sync']),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'happenedOn': formatLedgerDate(happenedOn),
      'cowTag': cowTag,
      'morningLitres': morningLitres,
      'eveningLitres': eveningLitres,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'sync': sync.wire,
    };
  }

  Map<String, dynamic> toRemoteRow() {
    return {
      'id': id,
      'happened_on': formatLedgerDate(happenedOn),
      'cow_tag': cowTag,
      'morning_litres': morningLitres,
      'evening_litres': eveningLitres,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

class LandParcel {
  const LandParcel({
    required this.id,
    required this.name,
    required this.use,
    required this.acres,
    this.yieldNote = '',
  });

  final String id;
  final String name;
  final LandUse use;
  final double acres;
  final String yieldNote;

  factory LandParcel.fromJson(Map<String, dynamic> json) {
    return LandParcel(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      use: LandUse.parse(_string(json, 'use', alt: 'land_use')),
      acres: _double(json['acres']),
      yieldNote: _optional(json['yieldNote'] ?? json['yield_note']) ?? '',
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'name': name,
      'use': use.wire,
      'acres': acres,
      'yieldNote': yieldNote,
    };
  }
}

/// Gestation used for the attention list. Pigs 114 days, cattle 283 days.
DateTime expectedBirth(Species species, DateTime servedOn) {
  final days = species == Species.pig ? 114 : 283;
  return DateTime(servedOn.year, servedOn.month, servedOn.day + days);
}

class FarmLedger {
  const FarmLedger({
    this.births = const [],
    this.deaths = const [],
    this.feedUses = const [],
    this.purchases = const [],
    this.breeding = const [],
    this.weights = const [],
    this.health = const [],
    this.sales = const [],
    this.expenses = const [],
    this.milk = const [],
    this.land = const [],
  });

  static const empty = FarmLedger();

  final List<BirthRecord> births;
  final List<DeathRecord> deaths;
  final List<FeedUse> feedUses;
  final List<FeedPurchase> purchases;
  final List<BreedingService> breeding;
  final List<WeightRecord> weights;
  final List<HealthEvent> health;
  final List<SaleRecord> sales;
  final List<ExpenseRecord> expenses;
  final List<MilkYield> milk;
  final List<LandParcel> land;

  FarmLedger copyWith({
    List<BirthRecord>? births,
    List<DeathRecord>? deaths,
    List<FeedUse>? feedUses,
    List<FeedPurchase>? purchases,
    List<BreedingService>? breeding,
    List<WeightRecord>? weights,
    List<HealthEvent>? health,
    List<SaleRecord>? sales,
    List<ExpenseRecord>? expenses,
    List<MilkYield>? milk,
    List<LandParcel>? land,
  }) {
    return FarmLedger(
      births: births ?? this.births,
      deaths: deaths ?? this.deaths,
      feedUses: feedUses ?? this.feedUses,
      purchases: purchases ?? this.purchases,
      breeding: breeding ?? this.breeding,
      weights: weights ?? this.weights,
      health: health ?? this.health,
      sales: sales ?? this.sales,
      expenses: expenses ?? this.expenses,
      milk: milk ?? this.milk,
      land: land ?? this.land,
    );
  }

  int get pendingCount {
    var count = 0;
    for (final row in births) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in deaths) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in feedUses) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in purchases) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in breeding) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in weights) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in health) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in sales) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in expenses) {
      if (row.sync == SyncState.pending) count += 1;
    }
    for (final row in milk) {
      if (row.sync == SyncState.pending) count += 1;
    }
    return count;
  }

  factory FarmLedger.fromJson(Map<String, dynamic> json) {
    return FarmLedger(
      births: _rows(json['births'], BirthRecord.fromJson),
      deaths: _rows(json['deaths'], DeathRecord.fromJson),
      feedUses: _rows(json['feedUses'], FeedUse.fromJson),
      purchases: _rows(json['purchases'], FeedPurchase.fromJson),
      breeding: _rows(json['breeding'], BreedingService.fromJson),
      weights: _rows(json['weights'], WeightRecord.fromJson),
      health: _rows(json['health'], HealthEvent.fromJson),
      sales: _rows(json['sales'], SaleRecord.fromJson),
      expenses: _rows(json['expenses'], ExpenseRecord.fromJson),
      milk: _rows(json['milk'], MilkYield.fromJson),
      land: _rows(json['land'], LandParcel.fromJson),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'births': births.map((row) => row.toLocalJson()).toList(),
      'deaths': deaths.map((row) => row.toLocalJson()).toList(),
      'feedUses': feedUses.map((row) => row.toLocalJson()).toList(),
      'purchases': purchases.map((row) => row.toLocalJson()).toList(),
      'breeding': breeding.map((row) => row.toLocalJson()).toList(),
      'weights': weights.map((row) => row.toLocalJson()).toList(),
      'health': health.map((row) => row.toLocalJson()).toList(),
      'sales': sales.map((row) => row.toLocalJson()).toList(),
      'expenses': expenses.map((row) => row.toLocalJson()).toList(),
      'milk': milk.map((row) => row.toLocalJson()).toList(),
      'land': land.map((row) => row.toLocalJson()).toList(),
    };
  }
}

/// One row waiting to be upserted into Supabase.
class PendingOp {
  const PendingOp({required this.table, required this.row});

  final String table;
  final Map<String, dynamic> row;
}

List<PendingOp> pendingOps(FarmLedger ledger) {
  return [
    for (final row in ledger.births)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'births', row: row.toRemoteRow()),
    for (final row in ledger.deaths)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'mortalities', row: row.toRemoteRow()),
    for (final row in ledger.feedUses)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'feed_uses', row: row.toRemoteRow()),
    for (final row in ledger.purchases)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'feed_purchases', row: row.toRemoteRow()),
    for (final row in ledger.breeding)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'breeding_services', row: row.toRemoteRow()),
    for (final row in ledger.weights)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'weight_records', row: row.toRemoteRow()),
    for (final row in ledger.health)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'health_events', row: row.toRemoteRow()),
    for (final row in ledger.sales)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'sales', row: row.toRemoteRow()),
    for (final row in ledger.expenses)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'expenses', row: row.toRemoteRow()),
    for (final row in ledger.milk)
      if (row.sync == SyncState.pending)
        PendingOp(table: 'milk_yields', row: row.toRemoteRow()),
  ];
}

FarmLedger markSynced(FarmLedger ledger, Set<String> ids) {
  if (ids.isEmpty) {
    return ledger;
  }
  return FarmLedger(
    births: [
      for (final row in ledger.births)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    deaths: [
      for (final row in ledger.deaths)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    feedUses: [
      for (final row in ledger.feedUses)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    purchases: [
      for (final row in ledger.purchases)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    breeding: [
      for (final row in ledger.breeding)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    weights: [
      for (final row in ledger.weights)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    health: [
      for (final row in ledger.health)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    sales: [
      for (final row in ledger.sales)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    expenses: [
      for (final row in ledger.expenses)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    milk: [
      for (final row in ledger.milk)
        ids.contains(row.id) ? row.copyWith(sync: SyncState.synced) : row,
    ],
    land: ledger.land,
  );
}

String formatLedgerDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool sameMonth(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month;
}

String _string(Map<String, dynamic> json, String key, {String? alt}) {
  final value = json[key] ?? (alt == null ? null : json[alt]);
  if (value is! String || value.isEmpty) {
    throw FormatException('Ledger record is missing $key.');
  }
  return value;
}

String? _optional(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

int _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.parse(value);
  }
  return 0;
}

int? _optionalInt(Object? value) {
  if (value == null) {
    return null;
  }
  return _int(value);
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.isNotEmpty) {
    return double.parse(value);
  }
  return 0;
}

double? _optionalDouble(Object? value) {
  if (value == null) {
    return null;
  }
  return _double(value);
}

DateTime _date(Object? value) {
  final parsed = _optionalDate(value);
  if (parsed == null) {
    throw const FormatException('Ledger record is missing the day.');
  }
  return parsed;
}

DateTime? _optionalDate(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return DateTime(value.year, value.month, value.day);
  }
  if (value is String && value.isNotEmpty) {
    final parts = value.split('T').first.split('-');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    }
  }
  return null;
}

DateTime _time(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toUtc();
  }
  return DateTime.now().toUtc();
}

List<T> _rows<T>(Object? raw, T Function(Map<String, dynamic>) decode) {
  if (raw is! List) {
    return [];
  }
  return [
    for (final row in raw)
      if (row is Map) decode(Map<String, dynamic>.from(row)),
  ];
}
