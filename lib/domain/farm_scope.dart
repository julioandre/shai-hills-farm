import 'package:shai_hills_farm/domain/animal.dart';

/// One herd and one book for the whole farm, not one notebook per phone.
const farmScopeKey = 'farm';

/// The two yards. They are about 7 km apart.
class FarmSite {
  const FarmSite(this.id, this.name);

  final String id;
  final String name;
}

const farmSites = [
  FarmSite('piggery', 'Piggery Site'),
  FarmSite('cattle_poultry', 'Cattle/Poultry Site'),
];

/// A cost that is not for one yard, such as a shop receipt for the whole farm.
const allSitesId = 'all';

/// Sites on an expense. All sites is for a general receipt. Animals stay on a yard.
const expenseSites = [
  FarmSite(allSitesId, 'All sites'),
  FarmSite('piggery', 'Piggery Site'),
  FarmSite('cattle_poultry', 'Cattle/Poultry Site'),
];

/// Older sample rows used these ids. They still read as the two real sites.
String siteName(String? id) {
  for (final site in farmSites) {
    if (site.id == id) {
      return site.name;
    }
  }
  return switch (id) {
    'all' => 'All sites',
    'main' => 'Piggery Site',
    'north' => 'Cattle/Poultry Site',
    null || '' => 'Piggery Site',
    _ => id,
  };
}

const pigBreeds = ['Large White', 'Landrace', 'Duroc', 'Local'];

/// Local breeds on the ground now. Dairy breeds are ready for the crossbreeding plan.
const cattleBreeds = [
  'Sokoto Gudali',
  'Sanga',
  'West African Shorthorn',
  'Friesian',
  'Jersey',
  'Girolando',
];

const goatBreeds = ['West African Dwarf'];

const sheepBreeds = ['West African Dwarf', 'Sahel'];

const poultryBreeds = ['Local', 'Layer', 'Broiler'];

const dairyBreeds = ['Friesian', 'Jersey', 'Girolando'];

const feedTypes = [
  'Maize bran',
  'Soybean meal',
  'Wheat bran',
  'Salt',
  'Concentrate',
  'Forage',
];

/// What a vet bill was for. The amount is stored against this, not only "Vet".
const vetKinds = ['Vaccination', 'Treatment', 'Deworming', 'Visit'];

/// Fuel the farm actually buys.
const fuelTypes = ['Diesel', 'Petrol', 'Gas'];

const deathCauses = ['Disease', 'Injury', 'Unknown'];

const paymentMethods = ['Cash', 'MoMo', 'Bank'];

/// Houses 1,000 birds comfortably, and 2,000 if every pen is used.
const poultryComfortCapacity = 1000;
const poultryFullCapacity = 2000;

/// The land holding at Shai Hills.
const farmAcres = 20;

/// How the piggery is stocked: sows, boars, and growers.
enum PigClass {
  sow('Sows'),
  boar('Boars'),
  grower('Growers');

  const PigClass(this.label);

  final String label;
}

PigClass pigClassOf(Animal animal) {
  final tag = animal.tag.toUpperCase();
  if (tag.startsWith('BOAR')) {
    return PigClass.boar;
  }
  if (tag.startsWith('SOW')) {
    return PigClass.sow;
  }
  return PigClass.grower;
}
