import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';

const maxTagLength = 40;
const maxNoteLength = 200;

String? validateAnimal({
  required String tag,
  required Species? species,
  required Sex? sex,
  required AnimalStatus? status,
  required List<Animal> existing,
  String? exceptId,
}) {
  final trimmed = tag.trim();
  if (trimmed.isEmpty) {
    return 'Enter a tag or ID.';
  }
  if (trimmed.length > maxTagLength) {
    return 'Use a tag of $maxTagLength characters or fewer.';
  }
  if (species == null) {
    return 'Choose a species.';
  }
  if (sex == null) {
    return 'Choose female or male.';
  }
  if (status == null) {
    return 'Choose a status.';
  }
  final clash = existing.any(
    (animal) =>
        animal.id != exceptId &&
        animal.tag.toLowerCase() == trimmed.toLowerCase(),
  );
  if (clash) {
    return 'Tag $trimmed is already on the register.';
  }
  return null;
}

/// Litres or cedis. Accepts "12.5" and "12,5".
double? parseAmount(String raw) {
  var text = raw.trim().replaceAll(' ', '');
  if (text.isEmpty || text.startsWith('-')) {
    return null;
  }
  if (text.contains(',') && !text.contains('.')) {
    text = text.replaceAll(',', '.');
  }
  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) {
    return null;
  }
  return value;
}

String noteForSave(BookKind kind, String raw) {
  final trimmed = raw.trim();
  if (trimmed.isNotEmpty) {
    return trimmed;
  }
  return switch (kind) {
    BookKind.milk => 'Milk recorded',
    BookKind.sale => 'Sold',
    _ => trimmed,
  };
}

double? amountForSave(BookKind kind, String raw) {
  if (kind != BookKind.milk && kind != BookKind.sale) {
    return null;
  }
  final value = parseAmount(raw);
  if (value == null) {
    return null;
  }
  if (kind == BookKind.milk) {
    return (value * 10).round() / 10;
  }
  return (value * 100).round() / 100;
}

String? validateEntry({
  required BookKind? kind,
  required DateTime happenedOn,
  required String note,
  required String amountText,
  Animal? animal,
  required DateTime today,
}) {
  if (kind == null) {
    return 'Choose what happened.';
  }
  final day = DateTime(happenedOn.year, happenedOn.month, happenedOn.day);
  final end = DateTime(today.year, today.month, today.day);
  if (day.isAfter(end)) {
    return 'Use today or an earlier day.';
  }
  final storedNote = noteForSave(kind, note);
  if (storedNote.isEmpty) {
    return 'Write a short note.';
  }
  if (storedNote.length > maxNoteLength) {
    return 'Use a note of $maxNoteLength characters or fewer.';
  }
  final needsAnimal = kind == BookKind.sale || kind == BookKind.death;
  if (needsAnimal && animal == null) {
    return 'Choose the animal.';
  }
  if (kind == BookKind.milk &&
      animal != null &&
      animal.species != Species.cattle &&
      animal.species != Species.goat) {
    return 'Milk is for cattle or goats.';
  }
  if (kind == BookKind.milk || kind == BookKind.sale) {
    final amount = parseAmount(amountText);
    if (amount == null || amount <= 0) {
      return kind == BookKind.milk ? 'Enter the litres.' : 'Enter the cedis.';
    }
    if (kind == BookKind.milk && amount > 2000) {
      return 'Check the litres. One note can be up to 2,000.';
    }
    if (kind == BookKind.sale && amount > 1000000) {
      return 'Check the cedis. One note can be up to 1,000,000.';
    }
  }
  return null;
}
