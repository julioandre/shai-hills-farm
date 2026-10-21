import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/phone.dart';
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

  test('accepts a Ghana phone number and a 6-digit code', () {
    expect(
      validatePhone('123'),
      'Enter the phone number you use, like 024 412 0008.',
    );
    expect(validatePhone('024 412 0008'), isNull);
    expect(normalizePhone('+233244120008'), demoPhone);
    expect(displayPhone(demoPhone), '024 412 0008');
    expect(validateOtp('12345'), 'Enter the 6-digit code from the text.');
    expect(validateOtp('123456'), isNull);
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
