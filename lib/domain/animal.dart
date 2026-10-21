/// Livestock kept at Katamansu. Milk from cattle and goats is a book note.
enum Species {
  pig('pig', 'Pig', 'Pigs'),
  cattle('cattle', 'Cattle', 'Cattle'),
  goat('goat', 'Goat', 'Goats'),
  sheep('sheep', 'Sheep', 'Sheep'),
  poultry('poultry', 'Poultry', 'Poultry');

  const Species(this.wire, this.singular, this.plural);

  final String wire;
  final String singular;
  final String plural;

  static Species parse(String value) {
    for (final species in Species.values) {
      if (species.wire == value) {
        return species;
      }
    }
    throw FormatException('Unknown species "$value".');
  }
}

enum Sex {
  female('female', 'Female'),
  male('male', 'Male');

  const Sex(this.wire, this.label);

  final String wire;
  final String label;

  static Sex parse(String value) {
    for (final sex in Sex.values) {
      if (sex.wire == value) {
        return sex;
      }
    }
    throw FormatException('Unknown sex "$value".');
  }
}

/// Register status. Sold, dead, and culled stay on the register.
/// A sale or death in the farm book sets sold or dead.
enum AnimalStatus {
  onFarm('on_farm', 'On farm'),
  sold('sold', 'Sold'),
  slaughtered('slaughtered', 'Slaughtered'),
  dead('dead', 'Dead'),
  culled('culled', 'Culled');

  const AnimalStatus(this.wire, this.label);

  final String wire;
  final String label;

  static AnimalStatus parse(String value) {
    for (final status in AnimalStatus.values) {
      if (status.wire == value) {
        return status;
      }
    }
    throw FormatException('Unknown status "$value".');
  }
}

/// What a pig or a cow has grown into. Other species do not use this.
enum AnimalStage {
  grower('grower', 'Grower', Species.pig),
  sow('sow', 'Sow', Species.pig),
  boar('boar', 'Boar', Species.pig),
  heifer('heifer', 'Heifer', Species.cattle),
  dairy('dairy', 'Dairy', Species.cattle),
  bull('bull', 'Bull', Species.cattle),
  cow('cow', 'Cow', Species.cattle);

  const AnimalStage(this.wire, this.label, this.species);

  final String wire;
  final String label;
  final Species species;

  static AnimalStage? parse(String? value) {
    for (final stage in AnimalStage.values) {
      if (stage.wire == value) {
        return stage;
      }
    }
    return null;
  }

  static List<AnimalStage> forSpecies(Species? species) {
    return [
      for (final stage in AnimalStage.values)
        if (stage.species == species) stage,
    ];
  }
}

/// How the animal joined the herd.
enum OriginType {
  born('born', 'Born on farm'),
  purchased('purchased', 'Purchased');

  const OriginType(this.wire, this.label);

  final String wire;
  final String label;

  static OriginType parse(String? value) {
    for (final origin in OriginType.values) {
      if (origin.wire == value) {
        return origin;
      }
    }
    return OriginType.born;
  }
}

/// Why a cull was decided.
enum CullReason {
  productivity('productivity', 'Low productivity'),
  age('age', 'Age'),
  disease('disease', 'Disease'),
  genetics('genetics', 'Poor genetics');

  const CullReason(this.wire, this.label);

  final String wire;
  final String label;

  static CullReason? parse(String? value) {
    for (final reason in CullReason.values) {
      if (reason.wire == value) {
        return reason;
      }
    }
    return null;
  }
}

class Animal {
  const Animal({
    required this.id,
    required this.tag,
    required this.species,
    required this.sex,
    required this.status,
    required this.updatedAt,
    this.breed,
    this.dateOfBirth,
    this.motherId,
    this.fatherId,
    this.weightKg,
    this.locationId,
    this.origin = OriginType.born,
    this.stage,
    this.dairy = false,
    this.motherTag,
    this.fatherTag,
    this.birthWeightKg,
    this.birthLocationId,
    this.sourceFarm,
    this.supplierName,
    this.purchaseDate,
    this.purchaseWeightKg,
    this.purchasePrice,
    this.transportCost,
    this.saleDate,
    this.saleWeightKg,
    this.salePrice,
    this.saleCost,
    this.buyerName,
    this.buyerContact,
    this.slaughterDate,
    this.liveWeightKg,
    this.carcassWeightKg,
    this.slaughterDestination,
    this.deathDate,
    this.deathWeightKg,
    this.deathCause,
    this.deathNote,
    this.hasDeathPhoto = false,
    this.cullDate,
    this.cullWeightKg,
    this.cullReason,
  });

  final String id;
  final String tag;
  final Species species;
  final Sex sex;
  final AnimalStatus status;
  final DateTime updatedAt;
  final String? breed;
  final DateTime? dateOfBirth;
  final String? motherId;
  final String? fatherId;
  final double? weightKg;
  final String? locationId;
  final OriginType origin;
  final AnimalStage? stage;
  final bool dairy;
  final String? motherTag;
  final String? fatherTag;
  final double? birthWeightKg;
  final String? birthLocationId;
  final String? sourceFarm;
  final String? supplierName;
  final DateTime? purchaseDate;
  final double? purchaseWeightKg;
  final double? purchasePrice;
  final double? transportCost;
  final DateTime? saleDate;
  final double? saleWeightKg;
  final double? salePrice;

  /// Extra cost of the sale, such as transport to market.
  final double? saleCost;
  final String? buyerName;
  final String? buyerContact;
  final DateTime? slaughterDate;
  final double? liveWeightKg;
  final double? carcassWeightKg;
  final String? slaughterDestination;
  final DateTime? deathDate;
  final double? deathWeightKg;
  final String? deathCause;
  final String? deathNote;
  final bool hasDeathPhoto;
  final DateTime? cullDate;
  final double? cullWeightKg;
  final CullReason? cullReason;

  Animal copyWith({
    String? tag,
    Species? species,
    Sex? sex,
    AnimalStatus? status,
    DateTime? updatedAt,
    String? breed,
    DateTime? dateOfBirth,
    String? motherId,
    String? fatherId,
    double? weightKg,
    String? locationId,
    OriginType? origin,
    AnimalStage? stage,
    bool? dairy,
    String? motherTag,
    String? fatherTag,
    double? birthWeightKg,
    String? birthLocationId,
    String? sourceFarm,
    String? supplierName,
    DateTime? purchaseDate,
    double? purchaseWeightKg,
    double? purchasePrice,
    double? transportCost,
    DateTime? saleDate,
    double? saleWeightKg,
    double? salePrice,
    double? saleCost,
    String? buyerName,
    String? buyerContact,
    DateTime? slaughterDate,
    double? liveWeightKg,
    double? carcassWeightKg,
    String? slaughterDestination,
    DateTime? deathDate,
    double? deathWeightKg,
    String? deathCause,
    String? deathNote,
    bool? hasDeathPhoto,
    DateTime? cullDate,
    double? cullWeightKg,
    CullReason? cullReason,
  }) {
    return Animal(
      id: id,
      tag: tag ?? this.tag,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      breed: breed ?? this.breed,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      motherId: motherId ?? this.motherId,
      fatherId: fatherId ?? this.fatherId,
      weightKg: weightKg ?? this.weightKg,
      locationId: locationId ?? this.locationId,
      origin: origin ?? this.origin,
      stage: stage ?? this.stage,
      dairy: dairy ?? this.dairy,
      motherTag: motherTag ?? this.motherTag,
      fatherTag: fatherTag ?? this.fatherTag,
      birthWeightKg: birthWeightKg ?? this.birthWeightKg,
      birthLocationId: birthLocationId ?? this.birthLocationId,
      sourceFarm: sourceFarm ?? this.sourceFarm,
      supplierName: supplierName ?? this.supplierName,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      purchaseWeightKg: purchaseWeightKg ?? this.purchaseWeightKg,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      transportCost: transportCost ?? this.transportCost,
      saleDate: saleDate ?? this.saleDate,
      saleWeightKg: saleWeightKg ?? this.saleWeightKg,
      salePrice: salePrice ?? this.salePrice,
      saleCost: saleCost ?? this.saleCost,
      buyerName: buyerName ?? this.buyerName,
      buyerContact: buyerContact ?? this.buyerContact,
      slaughterDate: slaughterDate ?? this.slaughterDate,
      liveWeightKg: liveWeightKg ?? this.liveWeightKg,
      carcassWeightKg: carcassWeightKg ?? this.carcassWeightKg,
      slaughterDestination: slaughterDestination ?? this.slaughterDestination,
      deathDate: deathDate ?? this.deathDate,
      deathWeightKg: deathWeightKg ?? this.deathWeightKg,
      deathCause: deathCause ?? this.deathCause,
      deathNote: deathNote ?? this.deathNote,
      hasDeathPhoto: hasDeathPhoto ?? this.hasDeathPhoto,
      cullDate: cullDate ?? this.cullDate,
      cullWeightKg: cullWeightKg ?? this.cullWeightKg,
      cullReason: cullReason ?? this.cullReason,
    );
  }

  factory Animal.fromJson(Map<String, dynamic> json) {
    final updated = json['updatedAt'] ?? json['updated_at'];
    final born = json['dateOfBirth'] ?? json['date_of_birth'];
    return Animal(
      id: _requiredString(json, 'id'),
      tag: _requiredString(json, 'tag', alt: 'tag_number'),
      species: Species.parse(_requiredString(json, 'species')),
      sex: Sex.parse(_requiredString(json, 'sex')),
      status: AnimalStatus.parse(_requiredString(json, 'status')),
      updatedAt: _parseTime(updated),
      breed: _optionalString(json['breed']),
      dateOfBirth: born == null ? null : _parseDate(born),
      motherId: _optionalString(json['motherId'] ?? json['mother_id']),
      fatherId: _optionalString(json['fatherId'] ?? json['father_id']),
      weightKg: _optionalDouble(json['weightKg'] ?? json['weight_kg']),
      locationId: _optionalString(json['locationId'] ?? json['location_id']),
      origin: OriginType.parse(_optionalString(json['origin'])),
      stage: AnimalStage.parse(_optionalString(json['stage'])),
      dairy: json['dairy'] == true,
      motherTag: _optionalString(json['motherTag'] ?? json['mother_tag']),
      fatherTag: _optionalString(json['fatherTag'] ?? json['father_tag']),
      birthWeightKg: _optionalDouble(
        json['birthWeightKg'] ?? json['birth_weight_kg'],
      ),
      birthLocationId: _optionalString(
        json['birthLocationId'] ?? json['birth_location_id'],
      ),
      sourceFarm: _optionalString(json['sourceFarm'] ?? json['source_farm']),
      supplierName: _optionalString(
        json['supplierName'] ?? json['supplier_name'],
      ),
      purchaseDate: _parseDate(json['purchaseDate'] ?? json['purchase_date']),
      purchaseWeightKg: _optionalDouble(
        json['purchaseWeightKg'] ?? json['purchase_weight_kg'],
      ),
      purchasePrice: _optionalDouble(
        json['purchasePrice'] ?? json['purchase_price'],
      ),
      transportCost: _optionalDouble(
        json['transportCost'] ?? json['transport_cost'],
      ),
      saleDate: _parseDate(json['saleDate'] ?? json['sale_date']),
      saleWeightKg: _optionalDouble(
        json['saleWeightKg'] ?? json['sale_weight_kg'],
      ),
      salePrice: _optionalDouble(json['salePrice'] ?? json['sale_price']),
      saleCost: _optionalDouble(json['saleCost'] ?? json['sale_cost']),
      buyerName: _optionalString(json['buyerName'] ?? json['buyer_name']),
      buyerContact: _optionalString(
        json['buyerContact'] ?? json['buyer_contact'],
      ),
      slaughterDate: _parseDate(
        json['slaughterDate'] ?? json['slaughter_date'],
      ),
      liveWeightKg: _optionalDouble(
        json['liveWeightKg'] ?? json['live_weight_kg'],
      ),
      carcassWeightKg: _optionalDouble(
        json['carcassWeightKg'] ?? json['carcass_weight_kg'],
      ),
      slaughterDestination: _optionalString(
        json['slaughterDestination'] ?? json['slaughter_destination'],
      ),
      deathDate: _parseDate(json['deathDate'] ?? json['death_date']),
      deathWeightKg: _optionalDouble(
        json['deathWeightKg'] ?? json['death_weight_kg'],
      ),
      deathCause: _optionalString(json['deathCause'] ?? json['death_cause']),
      deathNote: _optionalString(json['deathNote'] ?? json['death_note']),
      hasDeathPhoto:
          json['hasDeathPhoto'] == true || json['has_death_photo'] == true,
      cullDate: _parseDate(json['cullDate'] ?? json['cull_date']),
      cullWeightKg: _optionalDouble(
        json['cullWeightKg'] ?? json['cull_weight_kg'],
      ),
      cullReason: CullReason.parse(
        _optionalString(json['cullReason'] ?? json['cull_reason']),
      ),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'tag': tag,
      'species': species.wire,
      'sex': sex.wire,
      'status': status.wire,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'breed': breed,
      'dateOfBirth': dateOfBirth == null ? null : _formatDate(dateOfBirth!),
      'motherId': motherId,
      'fatherId': fatherId,
      'weightKg': weightKg,
      'locationId': locationId,
      'origin': origin.wire,
      'stage': stage?.wire,
      'dairy': dairy,
      'motherTag': motherTag,
      'fatherTag': fatherTag,
      'birthWeightKg': birthWeightKg,
      'birthLocationId': birthLocationId,
      'sourceFarm': sourceFarm,
      'supplierName': supplierName,
      'purchaseDate': purchaseDate == null ? null : _formatDate(purchaseDate!),
      'purchaseWeightKg': purchaseWeightKg,
      'purchasePrice': purchasePrice,
      'transportCost': transportCost,
      'saleDate': saleDate == null ? null : _formatDate(saleDate!),
      'saleWeightKg': saleWeightKg,
      'salePrice': salePrice,
      'saleCost': saleCost,
      'buyerName': buyerName,
      'buyerContact': buyerContact,
      'slaughterDate': slaughterDate == null
          ? null
          : _formatDate(slaughterDate!),
      'liveWeightKg': liveWeightKg,
      'carcassWeightKg': carcassWeightKg,
      'slaughterDestination': slaughterDestination,
      'deathDate': deathDate == null ? null : _formatDate(deathDate!),
      'deathWeightKg': deathWeightKg,
      'deathCause': deathCause,
      'deathNote': deathNote,
      'hasDeathPhoto': hasDeathPhoto,
      'cullDate': cullDate == null ? null : _formatDate(cullDate!),
      'cullWeightKg': cullWeightKg,
      'cullReason': cullReason?.wire,
    };
  }

  Map<String, dynamic> toSupabaseRow(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'tag': tag,
      'species': species.wire,
      'sex': sex.wire,
      'status': status.wire,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'breed': breed,
      'date_of_birth': dateOfBirth == null ? null : _formatDate(dateOfBirth!),
      'mother_id': motherId,
      'father_id': fatherId,
      'weight_kg': weightKg,
      'location_id': locationId,
      'origin': origin.wire,
      'stage': stage?.wire,
      'dairy': dairy,
      'mother_tag': motherTag,
      'father_tag': fatherTag,
      'birth_weight_kg': birthWeightKg,
      'birth_location_id': birthLocationId,
      'source_farm': sourceFarm,
      'supplier_name': supplierName,
      'purchase_date': purchaseDate == null ? null : _formatDate(purchaseDate!),
      'purchase_weight_kg': purchaseWeightKg,
      'purchase_price': purchasePrice,
      'transport_cost': transportCost,
      'sale_date': saleDate == null ? null : _formatDate(saleDate!),
      'sale_weight_kg': saleWeightKg,
      'sale_price': salePrice,
      'sale_cost': saleCost,
      'buyer_name': buyerName,
      'buyer_contact': buyerContact,
      'slaughter_date': slaughterDate == null
          ? null
          : _formatDate(slaughterDate!),
      'live_weight_kg': liveWeightKg,
      'carcass_weight_kg': carcassWeightKg,
      'slaughter_destination': slaughterDestination,
      'death_date': deathDate == null ? null : _formatDate(deathDate!),
      'death_weight_kg': deathWeightKg,
      'death_cause': deathCause,
      'death_note': deathNote,
      'has_death_photo': hasDeathPhoto,
      'cull_date': cullDate == null ? null : _formatDate(cullDate!),
      'cull_weight_kg': cullWeightKg,
      'cull_reason': cullReason?.wire,
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key, {String? alt}) {
  final value = json[key] ?? (alt == null ? null : json[alt]);
  if (value is! String || value.isEmpty) {
    throw FormatException('Animal record is missing $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

double? _optionalDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String && value.isNotEmpty) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _parseDate(Object? value) {
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

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

DateTime _parseTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.parse(value).toUtc();
  }
  throw const FormatException('Animal record is missing updated time.');
}

List<Animal> sortAnimals(List<Animal> animals) {
  final sorted = [...animals];
  sorted.sort((a, b) {
    final byTag = a.tag.toLowerCase().compareTo(b.tag.toLowerCase());
    if (byTag != 0) {
      return byTag;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}
