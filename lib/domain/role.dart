import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

/// Who is signed in, and what that person is allowed to do.
///
/// Admin runs the farm. A manager runs animals, breeding, feed, and reports.
/// A worker records the day for the herds an admin has assigned.
enum FarmRole {
  admin('admin', 'Admin'),
  manager('manager', 'Farm manager'),
  worker('worker', 'Farm worker');

  const FarmRole(this.wire, this.label);

  final String wire;
  final String label;

  static FarmRole parse(String value) {
    for (final role in FarmRole.values) {
      if (role.wire == value) {
        return role;
      }
    }
    throw FormatException('Unknown role "$value".');
  }
}

class FarmPerson {
  const FarmPerson({
    required this.userId,
    required this.phone,
    required this.role,
    this.name = '',
    this.herds = const {},
  });

  final String userId;
  final String phone;
  final FarmRole role;
  final String name;

  /// Name when one is saved, otherwise the phone number.
  String get label {
    final trimmed = name.trim();
    return trimmed.isEmpty ? phone : trimmed;
  }

  /// Empty means every herd. A worker with pigs and cattle sees both.
  final Set<Species> herds;
}

/// Permissions for Katamansu Spice Farm. Workers never see money.
class FarmAccess {
  const FarmAccess(this.role, {this.herds = const {}});

  final FarmRole role;

  /// Species a worker may open. Empty means the admin has not narrowed them.
  final Set<Species> herds;

  /// Managers and admins see every herd. A worker with no herds picked yet does too.
  bool get seesEveryHerd => role != FarmRole.worker || herds.isEmpty;

  bool allows(Species species) {
    if (seesEveryHerd) {
      return true;
    }
    if (herds.contains(species)) {
      return true;
    }
    return species == Species.sheep && herds.contains(Species.goat);
  }

  List<Species> get speciesChoices {
    if (seesEveryHerd) {
      return Species.values;
    }
    return [
      for (final species in Species.values)
        if (allows(species)) species,
    ];
  }

  String get herdLabel {
    if (seesEveryHerd) {
      return 'All animals';
    }
    final names = <String>[
      if (herds.contains(Species.pig)) 'Pigs',
      if (herds.contains(Species.cattle)) 'Cattle',
      if (herds.contains(Species.goat)) 'Goats',
      if (herds.contains(Species.sheep) && !herds.contains(Species.goat))
        'Sheep',
      if (herds.contains(Species.poultry)) 'Poultry',
    ];
    return names.join(', ');
  }

  bool get manageUsers => role == FarmRole.admin;

  bool get managePermissions => role == FarmRole.admin;

  bool get viewFinancials => role != FarmRole.worker;

  bool get manageAnimals => role != FarmRole.worker;

  bool get manageBreeding => role != FarmRole.worker;

  bool get manageFeedPurchases => role != FarmRole.worker;

  bool get recordBirths => true;

  bool get recordDeaths => true;

  bool get recordFeedUse => true;

  bool get viewHerd => true;

  bool get viewAttention => true;

  /// Plain lines for the signed-in person. Money is left off a worker's list.
  List<String> get allowed {
    return [
      'Look up ${seesEveryHerd ? 'animals' : herdLabel.toLowerCase()}',
      'Record a birth, a death, or sickness',
      'Give feed and mix a batch',
      'Weigh an animal',
      'Record a vaccine',
      if (manageFeedPurchases) 'Record feed bought on Money',
      if (viewFinancials) 'See sales and expenses',
      if (manageUsers) 'Choose who is a manager or a worker',
    ];
  }
}

/// Ledger rows a worker is allowed to see. Managers and admins get the whole book.
FarmLedger scopeLedger(
  FarmLedger ledger,
  FarmAccess access,
  List<Animal> animals,
) {
  if (access.seesEveryHerd) {
    return ledger;
  }
  bool tagOk(String tag) {
    for (final animal in animals) {
      if (animal.tag == tag) {
        return access.allows(animal.species);
      }
    }
    return true;
  }

  final milkOk = access.allows(Species.cattle) || access.allows(Species.goat);
  return ledger.copyWith(
    births: [
      for (final row in ledger.births)
        if (access.allows(row.species)) row,
    ],
    deaths: [
      for (final row in ledger.deaths)
        if (access.allows(row.species)) row,
    ],
    feedUses: [
      for (final row in ledger.feedUses)
        if (access.allows(row.species)) row,
    ],
    breeding: [
      for (final row in ledger.breeding)
        if (access.allows(row.species)) row,
    ],
    weights: [
      for (final row in ledger.weights)
        if (access.allows(row.species)) row,
    ],
    health: [
      for (final row in ledger.health)
        if (tagOk(row.animalTag)) row,
    ],
    milk: milkOk
        ? [
            for (final row in ledger.milk)
              if (tagOk(row.cowTag)) row,
          ]
        : const [],
  );
}
