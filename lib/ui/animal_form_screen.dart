import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({
    super.key,
    required this.herd,
    this.animal,
    this.ledger = FarmLedger.empty,
    this.initialStatus,
    this.initialSpecies,
    this.speciesChoices = const [],
  });

  final HerdController herd;
  final Animal? animal;
  final FarmLedger ledger;
  final AnimalStatus? initialStatus;
  final Species? initialSpecies;

  /// Empty means every species. A worker only sees the herds they look after.
  final List<Species> speciesChoices;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  late final TextEditingController _tag;
  late final TextEditingController _mother;
  late final TextEditingController _father;
  late final TextEditingController _birthDate;
  late final TextEditingController _birthWeight;
  late final TextEditingController _source;
  late final TextEditingController _supplier;
  late final TextEditingController _purchaseDate;
  late final TextEditingController _purchaseWeight;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _transport;
  late final TextEditingController _saleDate;
  late final TextEditingController _saleWeight;
  late final TextEditingController _salePrice;
  late final TextEditingController _saleCost;
  late final TextEditingController _buyer;
  late final TextEditingController _buyerContact;
  late final TextEditingController _slaughterDate;
  late final TextEditingController _liveWeight;
  late final TextEditingController _carcass;
  late final TextEditingController _destination;
  late final TextEditingController _deathDate;
  late final TextEditingController _deathWeight;
  late final TextEditingController _deathNote;
  late final TextEditingController _cullDate;
  late final TextEditingController _cullWeight;
  Species? _species;
  Sex? _sex;
  AnimalStage? _stage;
  String? _breed;
  int _young = 1;
  final List<TextEditingController> _extraTags = [];
  final List<Sex?> _extraSex = [];
  String _location = farmSites.first.id;
  late AnimalStatus _status;
  late OriginType _origin;
  String? _deathCause;
  CullReason? _cullReason;
  bool _hasDeathPhoto = false;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.animal != null;

  List<Species> get _speciesChoices {
    if (widget.speciesChoices.isEmpty) {
      return Species.values;
    }
    return widget.speciesChoices;
  }

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    final today = _today();
    _tag = TextEditingController(text: animal?.tag ?? '');
    _mother = TextEditingController(text: animal?.motherTag ?? '');
    _father = TextEditingController(text: animal?.fatherTag ?? '');
    _birthDate = TextEditingController(
      text: _iso(animal?.dateOfBirth ?? today),
    );
    _birthWeight = TextEditingController(text: _num(animal?.birthWeightKg));
    _source = TextEditingController(text: animal?.sourceFarm ?? '');
    _supplier = TextEditingController(text: animal?.supplierName ?? '');
    _purchaseDate = TextEditingController(
      text: _iso(animal?.purchaseDate ?? today),
    );
    _purchaseWeight = TextEditingController(
      text: _num(animal?.purchaseWeightKg),
    );
    _purchasePrice = TextEditingController(text: _num(animal?.purchasePrice));
    _transport = TextEditingController(text: _num(animal?.transportCost));
    _saleDate = TextEditingController(text: _iso(animal?.saleDate ?? today));
    _saleWeight = TextEditingController(text: _num(animal?.saleWeightKg));
    _salePrice = TextEditingController(text: _num(animal?.salePrice));
    _saleCost = TextEditingController(text: _num(animal?.saleCost));
    _buyer = TextEditingController(text: animal?.buyerName ?? '');
    _buyerContact = TextEditingController(text: animal?.buyerContact ?? '');
    _slaughterDate = TextEditingController(
      text: _iso(animal?.slaughterDate ?? today),
    );
    _liveWeight = TextEditingController(text: _num(animal?.liveWeightKg));
    _carcass = TextEditingController(text: _num(animal?.carcassWeightKg));
    _destination = TextEditingController(
      text: animal?.slaughterDestination ?? '',
    );
    _deathDate = TextEditingController(text: _iso(animal?.deathDate ?? today));
    _deathWeight = TextEditingController(text: _num(animal?.deathWeightKg));
    _deathNote = TextEditingController(text: animal?.deathNote ?? '');
    _cullDate = TextEditingController(text: _iso(animal?.cullDate ?? today));
    _cullWeight = TextEditingController(text: _num(animal?.cullWeightKg));
    _species = animal?.species ?? widget.initialSpecies;
    _sex = animal?.sex;
    _stage =
        animal?.stage ?? (animal?.dairy == true ? AnimalStage.dairy : null);
    _breed = animal?.breed;
    _location = animal?.locationId ?? farmSites.first.id;
    _status = animal?.status ?? widget.initialStatus ?? AnimalStatus.onFarm;
    _origin = animal?.origin ?? OriginType.born;
    _deathCause = animal?.deathCause;
    _cullReason = animal?.cullReason;
    _hasDeathPhoto = animal?.hasDeathPhoto ?? false;
  }

  @override
  void dispose() {
    for (final controller in [
      _tag,
      _mother,
      _father,
      _birthDate,
      _birthWeight,
      _source,
      _supplier,
      _purchaseDate,
      _purchaseWeight,
      _purchasePrice,
      _transport,
      _saleDate,
      _saleWeight,
      _salePrice,
      _saleCost,
      _buyer,
      _buyerContact,
      _slaughterDate,
      _liveWeight,
      _carcass,
      _destination,
      _deathDate,
      _deathWeight,
      _deathNote,
      _cullDate,
      _cullWeight,
      ..._extraTags,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    if (_species == null || _sex == null) {
      setState(() {
        _saving = false;
        _error = _species == null
            ? 'Choose a species.'
            : 'Choose female or male.';
      });
      return;
    }
    final litter = !_editing && _origin == OriginType.born && _young > 1;
    if (litter && _extraSex.any((sex) => sex == null)) {
      setState(() {
        _saving = false;
        _error = 'Choose female or male for each one born.';
      });
      return;
    }
    final id = widget.animal?.id ?? newId();
    final animal = _buildAnimal(id: id, tag: _tag.text.trim(), sex: _sex!);
    final batch = <Animal>[
      animal,
      if (litter)
        for (var index = 0; index < _extraTags.length; index++)
          _buildAnimal(
            id: newId(),
            tag: _extraTags[index].text.trim(),
            sex: _extraSex[index]!,
          ),
    ];
    var seen = widget.herd.animals;
    for (final born in batch) {
      final problem = traceProblem(born, seen);
      if (problem != null) {
        setState(() {
          _saving = false;
          _error = problem;
        });
        return;
      }
      seen = [...seen, born];
    }
    for (final born in batch) {
      final error = await widget.herd.save(born);
      if (!mounted) {
        return;
      }
      if (error != null) {
        setState(() {
          _saving = false;
          _error = error;
        });
        return;
      }
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Animal _buildAnimal({
    required String id,
    required String tag,
    required Sex sex,
  }) {
    return Animal(
      id: id,
      tag: tag,
      species: _species!,
      sex: sex,
      status: _status,
      updatedAt: DateTime.now().toUtc(),
      breed: _breed,
      stage: _stage,
      locationId: _location,
      origin: _origin,
      dairy: _species == Species.cattle && _stage == AnimalStage.dairy,
      motherTag: _text(_mother),
      fatherTag: _text(_father),
      dateOfBirth: _date(_birthDate),
      birthWeightKg: _amount(_birthWeight),
      birthLocationId: _location,
      motherId: _idFor(_mother.text, id),
      fatherId: _idFor(_father.text, id),
      sourceFarm: _text(_source),
      supplierName: _text(_supplier),
      purchaseDate: _date(_purchaseDate),
      purchaseWeightKg: _amount(_purchaseWeight),
      purchasePrice: _amount(_purchasePrice),
      transportCost: _amount(_transport),
      saleDate: _date(_saleDate),
      saleWeightKg: _amount(_saleWeight),
      salePrice: _amount(_salePrice),
      saleCost: _amount(_saleCost),
      buyerName: _text(_buyer),
      buyerContact: _text(_buyerContact),
      slaughterDate: _date(_slaughterDate),
      liveWeightKg: _amount(_liveWeight),
      carcassWeightKg: _amount(_carcass),
      slaughterDestination: _text(_destination),
      deathDate: _date(_deathDate),
      deathWeightKg: _amount(_deathWeight),
      deathCause: _deathCause,
      deathNote: _text(_deathNote),
      hasDeathPhoto: _hasDeathPhoto,
      cullDate: _date(_cullDate),
      cullWeightKg: _amount(_cullWeight),
      cullReason: _cullReason,
    );
  }

  void _setYoung(int count) {
    final next = count.clamp(1, 12);
    setState(() {
      while (_extraTags.length < next - 1) {
        _extraTags.add(TextEditingController());
        _extraSex.add(null);
      }
      while (_extraTags.length > next - 1) {
        _extraTags.removeLast().dispose();
        _extraSex.removeLast();
      }
      _young = next;
    });
  }

  Future<void> _remove() async {
    final animal = widget.animal;
    if (animal == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove this animal?'),
          content: Text(
            '${animal.tag} will be deleted from the register. '
            'To keep the history, set the status to Sold, Slaughtered, Dead, or Culled.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              key: const Key('confirm-remove'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _saving = true);
    final error = await widget.herd.remove(animal.id);
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  Future<void> _attachPhoto() async {
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 70,
    );
    if (photo != null && mounted) {
      setState(() => _hasDeathPhoto = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perKg = pricePerKg(_amount(_salePrice), _amount(_saleWeight));
    final dressing = dressingPercent(_amount(_carcass), _amount(_liveWeight));
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit animal' : 'Register animal')),
      body: SafeArea(
        child: ListView(
          key: const Key('animal-form'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (widget.animal != null) ...[
              _Profile(
                animal: widget.animal!,
                herd: widget.herd.animals,
                ledger: widget.ledger,
              ),
              const SizedBox(height: 20),
            ],
            TextField(
              key: const Key('tag-field'),
              controller: _tag,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Tag or ID',
                hintText: 'Ear tag, flock ID, or batch',
              ),
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Species'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final species in _speciesChoices)
                  ChoiceChip(
                    key: Key('species-${species.wire}'),
                    label: Text(species.singular),
                    selected: _species == species,
                    onSelected: (_) => setState(() {
                      _species = species;
                      if (_stage != null && _stage!.species != species) {
                        _stage = null;
                      }
                    }),
                  ),
              ],
            ),
            if (AnimalStage.forSpecies(_species).isNotEmpty) ...[
              const SizedBox(height: 20),
              const _FieldLabel('Grown as'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final stage in AnimalStage.forSpecies(_species))
                    ChoiceChip(
                      key: Key('stage-${stage.wire}'),
                      label: Text(stage.label),
                      selected: _stage == stage,
                      onSelected: (_) => setState(() {
                        _stage = stage;
                        if (stage == AnimalStage.sow ||
                            stage == AnimalStage.heifer ||
                            stage == AnimalStage.dairy ||
                            stage == AnimalStage.cow) {
                          _sex = Sex.female;
                        }
                        if (stage == AnimalStage.boar ||
                            stage == AnimalStage.bull) {
                          _sex = Sex.male;
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Sex'),
            Wrap(
              spacing: 8,
              children: [
                for (final sex in Sex.values)
                  ChoiceChip(
                    key: Key('sex-${sex.wire}'),
                    label: Text(sex.label),
                    selected: _sex == sex,
                    onSelected: (_) => setState(() => _sex = sex),
                  ),
              ],
            ),
            if (_breeds.isNotEmpty) ...[
              const SizedBox(height: 20),
              const _FieldLabel('Breed'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final breed in _breeds)
                    ChoiceChip(
                      key: Key('breed-$breed'),
                      label: Text(breed),
                      selected: _breed == breed,
                      onSelected: (_) => setState(() {
                        _breed = breed;
                        if (dairyBreeds.contains(breed)) {
                          _stage = AnimalStage.dairy;
                        }
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Origin'),
            Wrap(
              spacing: 8,
              children: [
                for (final origin in OriginType.values)
                  ChoiceChip(
                    key: Key('origin-${origin.wire}'),
                    label: Text(origin.label),
                    selected: _origin == origin,
                    onSelected: (_) => setState(() => _origin = origin),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_origin == OriginType.born) ...[
              if (!_editing) ...[
                const _FieldLabel('How many born'),
                Row(
                  children: [
                    IconButton(
                      key: const Key('litter-less'),
                      onPressed: _young > 1
                          ? () => _setYoung(_young - 1)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text(
                      '$_young',
                      key: const Key('litter-count'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      key: const Key('litter-more'),
                      onPressed: _young < 12
                          ? () => _setYoung(_young + 1)
                          : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_young > 1)
                  Text(
                    'Each one needs a tag. They share the mother, the date, and the breed. The first tag is the one at the top.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                for (var index = 0; index < _extraTags.length; index++) ...[
                  TextField(
                    key: Key('litter-tag-$index'),
                    controller: _extraTags[index],
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(labelText: 'Tag ${index + 2}'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final sex in Sex.values)
                        ChoiceChip(
                          key: Key('litter-sex-$index-${sex.wire}'),
                          label: Text(sex.label),
                          selected: _extraSex[index] == sex,
                          onSelected: (_) =>
                              setState(() => _extraSex[index] = sex),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              TextField(
                key: const Key('mother-tag'),
                controller: _mother,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Mother tag'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('father-tag'),
                controller: _father,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Father tag'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('birth-date'),
                controller: _birthDate,
                decoration: const InputDecoration(
                  labelText: 'Birth date',
                  hintText: '2026-03-04',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('birth-weight'),
                controller: _birthWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Birth weight, kg',
                ),
              ),
            ] else ...[
              TextField(
                key: const Key('source-farm'),
                controller: _source,
                decoration: const InputDecoration(labelText: 'Source farm'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('supplier-name'),
                controller: _supplier,
                decoration: const InputDecoration(labelText: 'Supplier'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _purchaseDate,
                decoration: const InputDecoration(
                  labelText: 'Purchase date',
                  hintText: '2026-03-04',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('purchase-weight'),
                controller: _purchaseWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Purchase weight, kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('purchase-price'),
                controller: _purchasePrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Purchase price, cedis',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('transport-cost'),
                controller: _transport,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Transport cost, cedis',
                ),
              ),
            ],
            const SizedBox(height: 20),
            const _FieldLabel('Where'),
            Wrap(
              spacing: 8,
              children: [
                for (final site in farmSites)
                  ChoiceChip(
                    label: Text(site.name),
                    selected: _location == site.id,
                    onSelected: (_) => setState(() => _location = site.id),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            const _FieldLabel('Status'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in AnimalStatus.values)
                  ChoiceChip(
                    key: Key('status-${status.wire}'),
                    label: Text(status.label),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_status == AnimalStatus.sold) ...[
              TextField(
                key: const Key('sale-weight'),
                controller: _saleWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sale weight, kg'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale-price'),
                controller: _salePrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Sale price, cedis',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('sale-cost'),
                controller: _saleCost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Costs, cedis'),
              ),
              if (perKg != null) ...[
                const SizedBox(height: 8),
                Text('${formatCedis(perKg)} per kg'),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('buyer-name'),
                controller: _buyer,
                decoration: const InputDecoration(labelText: 'Buyer'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('buyer-contact'),
                controller: _buyerContact,
                decoration: const InputDecoration(labelText: 'Buyer contact'),
              ),
            ],
            if (_status == AnimalStatus.slaughtered) ...[
              TextField(
                key: const Key('live-weight'),
                controller: _liveWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Live weight, kg'),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('carcass-weight'),
                controller: _carcass,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Carcass weight, kg',
                ),
              ),
              if (dressing != null) ...[
                const SizedBox(height: 8),
                Text('Dressing ${dressing.round()}%'),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('slaughter-destination'),
                controller: _destination,
                decoration: const InputDecoration(
                  labelText: 'Where the meat went',
                ),
              ),
            ],
            if (_status == AnimalStatus.dead) ...[
              TextField(
                key: const Key('death-weight'),
                controller: _deathWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Weight at death, kg',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final cause in deathCauses)
                    ChoiceChip(
                      key: Key('death-$cause'),
                      label: Text(cause),
                      selected: _deathCause == cause,
                      onSelected: (_) => setState(() => _deathCause = cause),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _deathNote,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('death-photo'),
                onPressed: _attachPhoto,
                child: Text(_hasDeathPhoto ? 'Photo attached' : 'Add a photo'),
              ),
            ],
            if (_status == AnimalStatus.culled) ...[
              TextField(
                key: const Key('cull-weight'),
                controller: _cullWeight,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Weight, kg'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in CullReason.values)
                    ChoiceChip(
                      key: Key('cull-${reason.wire}'),
                      label: Text(reason.label),
                      selected: _cullReason == reason,
                      onSelected: (_) => setState(() => _cullReason = reason),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'On farm animals are included in the herd counts. '
              'Sold, slaughtered, dead, and culled stay on the register.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              NoticeBanner(
                key: const Key('form-error'),
                message: _error!,
                isError: true,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save-animal'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save animal'),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('remove-animal'),
                onPressed: _saving ? null : _remove,
                child: const Text('Remove from register'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<String> get _breeds {
    return switch (_species) {
      Species.pig => pigBreeds,
      Species.cattle => cattleBreeds,
      Species.goat => goatBreeds,
      Species.sheep => sheepBreeds,
      Species.poultry => poultryBreeds,
      null => const [],
    };
  }

  String? _idFor(String raw, String exceptId) {
    final wanted = raw.trim().toLowerCase();
    if (wanted.isEmpty) {
      return null;
    }
    for (final animal in widget.herd.animals) {
      if (animal.id != exceptId && animal.tag.toLowerCase() == wanted) {
        return animal.id;
      }
    }
    return null;
  }
}

class _Profile extends StatelessWidget {
  const _Profile({
    required this.animal,
    required this.herd,
    required this.ledger,
  });

  final Animal animal;
  final List<Animal> herd;
  final FarmLedger ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final events = lifeHistory(animal, ledger);
    final history = animalHealth(animal.tag, ledger);
    final tree = ancestry(animal, herd);
    final young = offspring(animal, herd);
    final perKg = pricePerKg(animal.salePrice, animal.saleWeightKg);
    final profit = profitEstimate(animal);
    final dressing = dressingPercent(
      animal.carcassWeightKg,
      animal.liveWeightKg,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Record', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Origin: ${animal.origin.label}'),
        if (animal.origin == OriginType.born) ...[
          Text('Mother: ${animal.motherTag ?? '—'}'),
          Text('Father: ${animal.fatherTag ?? '—'}'),
          if (animal.birthWeightKg != null)
            Text('Birth weight: ${animal.birthWeightKg!.round()} kg'),
          if (animal.dateOfBirth != null)
            Text('Date born: ${formatFarmDate(animal.dateOfBirth!)}'),
        ] else ...[
          Text('Source farm: ${animal.sourceFarm ?? '—'}'),
          if (animal.purchaseWeightKg != null)
            Text('Purchase weight: ${animal.purchaseWeightKg!.round()} kg'),
          if (animal.purchasePrice != null)
            Text('Purchase price: ${formatCedis(animal.purchasePrice!)}'),
          if (animal.purchaseDate != null)
            Text('Purchase date: ${formatFarmDate(animal.purchaseDate!)}'),
        ],
        if (animal.status == AnimalStatus.sold) ...[
          const Text('Status: Sold'),
          if (animal.saleWeightKg != null)
            Text('Sale weight: ${animal.saleWeightKg!.round()} kg'),
          if (animal.salePrice != null)
            Text('Sale price: ${formatCedis(animal.salePrice!)}'),
          if (animal.saleCost != null)
            Text('Costs: ${formatCedis(animal.saleCost!)}'),
        ],
        if (perKg != null) Text('${formatCedis(perKg)} per kg'),
        if (profit != null) Text('Profit estimate ${formatCedis(profit)}'),
        if (dressing != null) Text('Dressing ${dressing.round()}%'),
        const SizedBox(height: 12),
        Text('Vaccinations', style: theme.textTheme.titleMedium),
        ..._healthLines(history.vaccines, empty: 'No vaccinations yet.'),
        const SizedBox(height: 12),
        Text('Sickness', style: theme.textTheme.titleMedium),
        ..._healthLines(history.sickness, empty: 'No sickness recorded.'),
        if (tree.mother != null || tree.father != null || young.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Family', style: theme.textTheme.titleMedium),
          if (tree.mother != null)
            _KinLines(kin: tree.mother!, role: 'Mother', depth: 0),
          if (tree.father != null)
            _KinLines(kin: tree.father!, role: 'Father', depth: 0),
          if (young.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Young: ${young.map((child) => child.tag).join(', ')}'),
          ],
        ],
        if (events.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Life', style: theme.textTheme.titleMedium),
          for (final event in events)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${formatFarmDate(event.day)}\n${event.title}'
                '${event.detail.isEmpty ? '' : '\n${event.detail}'}',
              ),
            ),
        ],
      ],
    );
  }
}

List<Widget> _healthLines(List<HealthEvent> events, {required String empty}) {
  if (events.isEmpty) {
    return [const SizedBox(height: 4), Text(empty)];
  }
  return [
    for (final event in events)
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${formatFarmDate(event.happenedOn)}\n${event.kind.label}'
          '${event.note.isEmpty ? '' : '\n${event.note}'}',
        ),
      ),
  ];
}

class _KinLines extends StatelessWidget {
  const _KinLines({required this.kin, required this.role, required this.depth});

  final Kin kin;
  final String role;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 16.0, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${_kinRole(role, depth)}: ${kin.tag}'),
          if (kin.mother != null)
            _KinLines(kin: kin.mother!, role: 'Mother', depth: depth + 1),
          if (kin.father != null)
            _KinLines(kin: kin.father!, role: 'Father', depth: depth + 1),
        ],
      ),
    );
  }
}

String _kinRole(String side, int depth) {
  if (depth <= 0) {
    return side;
  }
  if (depth == 1) {
    return side == 'Mother' ? 'Grandmother' : 'Grandfather';
  }
  final greats = List.filled(depth - 1, 'Great').join(' ');
  final name = side == 'Mother' ? 'grandmother' : 'grandfather';
  return '$greats $name';
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _iso(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _num(double? value) {
  if (value == null) {
    return '';
  }
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toString();
}

String? _text(TextEditingController controller) {
  final value = controller.text.trim();
  return value.isEmpty ? null : value;
}

DateTime? _date(TextEditingController controller) {
  final parsed = DateTime.tryParse(controller.text.trim());
  if (parsed == null) {
    return null;
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

double? _amount(TextEditingController controller) {
  return double.tryParse(controller.text.trim());
}
