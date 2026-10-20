import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/validation.dart';

void main() {
  final existing = [
    Animal(
      id: 'a',
      tag: 'SH-PIG-01',
      species: Species.pig,
      sex: Sex.female,
      status: AnimalStatus.onFarm,
      updatedAt: DateTime.utc(2026, 10, 20),
    ),
  ];

  test('rejects a short password and a malformed email', () {
    expect(
      validateEmail('not-an-email'),
      'Enter the email address you use for the farm.',
    );
    expect(validateEmail('keeper@shaihills.farm'), isNull);
    expect(
      validatePassword('short'),
      'Use a password of at least 8 characters.',
    );
    expect(validatePassword('pasture-1'), isNull);
  });

  test('tag must be present, short enough, and unique ignoring case', () {
    expect(
      validateAnimal(
        tag: '   ',
        species: Species.goat,
        sex: Sex.male,
        status: AnimalStatus.onFarm,
        existing: existing,
      ),
      'Enter a tag or ID.',
    );
    expect(
      validateAnimal(
        tag: 'sh-pig-01',
        species: Species.pig,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        existing: existing,
      ),
      'Tag sh-pig-01 is already on the register.',
    );
    expect(
      validateAnimal(
        tag: 'sh-pig-01',
        species: Species.pig,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        existing: existing,
        exceptId: 'a',
      ),
      isNull,
    );
    expect(
      validateAnimal(
        tag: 'SH-GOAT-02',
        species: null,
        sex: Sex.female,
        status: AnimalStatus.onFarm,
        existing: existing,
      ),
      'Choose a species.',
    );
  });
}
