import 'package:flutter_test/flutter_test.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/herd_counts.dart';

void main() {
  Animal animal({
    required String tag,
    required Species species,
    required AnimalStatus status,
  }) {
    return Animal(
      id: tag,
      tag: tag,
      species: species,
      sex: Sex.female,
      status: status,
      updatedAt: DateTime.utc(2026, 10, 20),
    );
  }

  test('counts only animals marked on farm, by species', () {
    final counts = HerdCounts.fromAnimals([
      animal(tag: 'P1', species: Species.pig, status: AnimalStatus.onFarm),
      animal(tag: 'P2', species: Species.pig, status: AnimalStatus.onFarm),
      animal(tag: 'P3', species: Species.pig, status: AnimalStatus.sold),
      animal(tag: 'C1', species: Species.cattle, status: AnimalStatus.onFarm),
      animal(tag: 'C2', species: Species.cattle, status: AnimalStatus.dead),
      animal(tag: 'G1', species: Species.goat, status: AnimalStatus.onFarm),
      animal(tag: 'B1', species: Species.poultry, status: AnimalStatus.onFarm),
      animal(tag: 'B2', species: Species.poultry, status: AnimalStatus.sold),
    ]);

    expect(counts.pigs, 2);
    expect(counts.cattle, 1);
    expect(counts.goats, 1);
    expect(counts.poultry, 1);
    expect(counts.onFarm, 5);
    expect(counts.forSpecies(Species.pig), 2);
  });

  test('an empty register counts as zero', () {
    expect(HerdCounts.fromAnimals(const []).onFarm, 0);
    expect(HerdCounts.empty.cattle, 0);
  });
}
