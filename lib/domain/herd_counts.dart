import 'package:shai_hills_farm/domain/animal.dart';

/// Animals marked on farm, grouped by species.
class HerdCounts {
  const HerdCounts({
    required this.pigs,
    required this.cattle,
    required this.goats,
    required this.poultry,
  });

  static const empty = HerdCounts(pigs: 0, cattle: 0, goats: 0, poultry: 0);

  final int pigs;
  final int cattle;
  final int goats;
  final int poultry;

  int get onFarm => pigs + cattle + goats + poultry;

  int forSpecies(Species species) {
    return switch (species) {
      Species.pig => pigs,
      Species.cattle => cattle,
      Species.goat => goats,
      Species.poultry => poultry,
    };
  }

  factory HerdCounts.fromAnimals(Iterable<Animal> animals) {
    var pigs = 0;
    var cattle = 0;
    var goats = 0;
    var poultry = 0;
    for (final animal in animals) {
      if (animal.status != AnimalStatus.onFarm) {
        continue;
      }
      switch (animal.species) {
        case Species.pig:
          pigs += 1;
        case Species.cattle:
          cattle += 1;
        case Species.goat:
          goats += 1;
        case Species.poultry:
          poultry += 1;
      }
    }
    return HerdCounts(
      pigs: pigs,
      cattle: cattle,
      goats: goats,
      poultry: poultry,
    );
  }
}
