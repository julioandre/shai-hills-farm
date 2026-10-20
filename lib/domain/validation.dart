import 'package:shai_hills_farm/domain/animal.dart';

const maxTagLength = 40;

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String normalizeEmail(String raw) => raw.trim().toLowerCase();

String? validateEmail(String raw) {
  if (!_emailPattern.hasMatch(normalizeEmail(raw))) {
    return 'Enter the email address you use for the farm.';
  }
  return null;
}

String? validatePassword(String password) {
  if (password.length < 8) {
    return 'Use a password of at least 8 characters.';
  }
  return null;
}

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
