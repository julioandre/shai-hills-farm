import 'package:shai_hills_farm/domain/animal.dart';

/// One line in the farm book. A short note is enough.
enum BookKind {
  health('health', 'Health'),
  feed('feed', 'Feed'),
  breeding('breeding', 'Breeding'),
  milk('milk', 'Milk'),
  sale('sale', 'Sale'),
  death('death', 'Death');

  const BookKind(this.wire, this.label);

  final String wire;
  final String label;

  static BookKind parse(String value) {
    for (final kind in BookKind.values) {
      if (kind.wire == value) {
        return kind;
      }
    }
    throw FormatException('Unknown book entry "$value".');
  }
}

/// Sale and death take the animal out of the herd counts.
AnimalStatus? statusAfter(BookKind kind) {
  return switch (kind) {
    BookKind.sale => AnimalStatus.sold,
    BookKind.death => AnimalStatus.dead,
    _ => null,
  };
}

class FarmEntry {
  const FarmEntry({
    required this.id,
    required this.kind,
    required this.happenedOn,
    required this.note,
    required this.updatedAt,
    this.animalId,
    this.animalTag,
    this.amount,
  });

  final String id;
  final BookKind kind;
  final DateTime happenedOn;
  final String? animalId;
  final String? animalTag;
  final String note;

  /// Litres for milk, cedis for a sale.
  final double? amount;
  final DateTime updatedAt;

  factory FarmEntry.fromJson(Map<String, dynamic> json) {
    final happened = json['happenedOn'] ?? json['happened_on'];
    final updated = json['updatedAt'] ?? json['updated_at'];
    return FarmEntry(
      id: _requiredString(json, 'id'),
      kind: BookKind.parse(_requiredString(json, 'kind')),
      happenedOn: _parseDate(happened),
      animalId: _optionalString(json['animalId'] ?? json['animal_id']),
      animalTag: _optionalString(json['animalTag'] ?? json['animal_tag']),
      note: _requiredString(json, 'note'),
      amount: _parseAmount(json['amount']),
      updatedAt: _parseTime(updated),
    );
  }

  Map<String, dynamic> toLocalJson() {
    return {
      'id': id,
      'kind': kind.wire,
      'happenedOn': formatIsoDate(happenedOn),
      'animalId': animalId,
      'animalTag': animalTag,
      'note': note,
      'amount': amount,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabaseRow(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'kind': kind.wire,
      'happened_on': formatIsoDate(happenedOn),
      'animal_id': animalId,
      'animal_tag': animalTag,
      'note': note,
      'amount': amount,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

String formatIsoDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

const _months = [
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

String formatFarmDate(DateTime date) {
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

String farmDateLabel(DateTime day, DateTime today) {
  final formatted = formatFarmDate(day);
  final sameDay =
      day.year == today.year &&
      day.month == today.month &&
      day.day == today.day;
  if (sameDay) {
    return 'Today, $formatted';
  }
  return formatted;
}

String formatCedis(double amount) {
  final pesewas = (amount * 100).round();
  final whole = pesewas ~/ 100;
  final fraction = pesewas.abs() % 100;
  if (fraction == 0) {
    return 'GH₵ $whole';
  }
  return 'GH₵ $whole.${fraction.toString().padLeft(2, '0')}';
}

String formatLitres(double amount) {
  final tenths = (amount * 10).round();
  final whole = tenths ~/ 10;
  final fraction = tenths.abs() % 10;
  if (fraction == 0) {
    return '$whole L';
  }
  return '$whole.$fraction L';
}

String entryTitle(FarmEntry entry) {
  final amount = switch (entry.kind) {
    BookKind.milk => entry.amount == null ? null : formatLitres(entry.amount!),
    BookKind.sale => entry.amount == null ? null : formatCedis(entry.amount!),
    _ => null,
  };
  final tag = entry.animalTag;
  return [
    entry.kind.label,
    if (tag != null && tag.isNotEmpty) tag,
    ?amount,
  ].join(' · ');
}

List<FarmEntry> sortEntries(List<FarmEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    final byDay = b.happenedOn.compareTo(a.happenedOn);
    if (byDay != 0) {
      return byDay;
    }
    final byUpdate = b.updatedAt.compareTo(a.updatedAt);
    if (byUpdate != 0) {
      return byUpdate;
    }
    return a.id.compareTo(b.id);
  });
  return sorted;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Book entry is missing $key.');
  }
  return value;
}

String? _optionalString(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return value;
}

double? _parseAmount(Object? value) {
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

DateTime _parseDate(Object? value) {
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
  throw const FormatException('Book entry is missing the day.');
}

DateTime _parseTime(Object? value) {
  if (value is DateTime) {
    return value.toUtc();
  }
  if (value is String) {
    return DateTime.parse(value).toUtc();
  }
  throw const FormatException('Book entry is missing updated time.');
}
