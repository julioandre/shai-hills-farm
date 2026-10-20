/// Livestock kept at Shai Hills. Dairy breeds are a later sprint.
enum Species {
  pig('pig', 'Pig', 'Pigs'),
  cattle('cattle', 'Cattle', 'Cattle'),
  goat('goat', 'Goat', 'Goats'),
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

/// Register status. Sold and dead stay on the register.
/// Sales invoices and mortality records are later sprints.
enum AnimalStatus {
  onFarm('on_farm', 'On farm'),
  sold('sold', 'Sold'),
  dead('dead', 'Dead');

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

class Animal {
  const Animal({
    required this.id,
    required this.tag,
    required this.species,
    required this.sex,
    required this.status,
    required this.updatedAt,
  });

  final String id;
  final String tag;
  final Species species;
  final Sex sex;
  final AnimalStatus status;
  final DateTime updatedAt;

  Animal copyWith({
    String? tag,
    Species? species,
    Sex? sex,
    AnimalStatus? status,
    DateTime? updatedAt,
  }) {
    return Animal(
      id: id,
      tag: tag ?? this.tag,
      species: species ?? this.species,
      sex: sex ?? this.sex,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Animal.fromJson(Map<String, dynamic> json) {
    final updated = json['updatedAt'] ?? json['updated_at'];
    return Animal(
      id: _requiredString(json, 'id'),
      tag: _requiredString(json, 'tag'),
      species: Species.parse(_requiredString(json, 'species')),
      sex: Sex.parse(_requiredString(json, 'sex')),
      status: AnimalStatus.parse(_requiredString(json, 'status')),
      updatedAt: _parseTime(updated),
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
    };
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Animal record is missing $key.');
  }
  return value;
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
