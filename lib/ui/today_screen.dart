import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

/// Big buttons for the records a worker can make with little typing.
class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.ledger,
    required this.role,
    required this.localOnly,
    required this.onRegister,
    this.herds = const {},
  });

  final LedgerController ledger;
  final FarmRole role;
  final Set<Species> herds;
  final bool localOnly;
  final void Function({AnimalStatus? status, Species? species}) onRegister;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

enum _Job { weight, vaccine, sickness }

const _sicknessNotes = ['Not eating', 'Injury', 'Fever', 'Cough', 'Other'];

class _TodayScreenState extends State<TodayScreen> {
  _Job? _job;
  late Species _species;
  String _sickness = _sicknessNotes.first;
  String? _error;
  bool _saving = false;

  final _tag = TextEditingController();
  final _weight = TextEditingController();
  final _sicknessNote = TextEditingController();
  final _vaccineTags = <TextEditingController>[TextEditingController()];
  final _vaccineName = TextEditingController();
  final _vaccineDose = TextEditingController();
  DateTime? _vaccineDay;

  @override
  void initState() {
    super.initState();
    final choices = FarmAccess(widget.role, herds: widget.herds).speciesChoices;
    _species = choices.isEmpty ? Species.pig : choices.first;
  }

  @override
  void dispose() {
    _tag.dispose();
    _weight.dispose();
    _sicknessNote.dispose();
    for (final field in _vaccineTags) {
      field.dispose();
    }
    _vaccineName.dispose();
    _vaccineDose.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now().toUtc();
    final tag = _tag.text.trim();
    final error = switch (_job) {
      _Job.weight => await widget.ledger.addWeight(
        WeightRecord(
          id: newId(),
          animalTag: tag,
          species: _species,
          weighedOn: _today,
          weightKg: double.tryParse(_weight.text.trim()) ?? 0,
          updatedAt: now,
        ),
      ),
      _Job.vaccine => await _saveVaccines(now),
      _Job.sickness => await widget.ledger.addHealth(
        HealthEvent(
          id: newId(),
          animalTag: tag,
          kind: HealthKind.treatment,
          happenedOn: _today,
          note: _sicknessNote.text.trim().isEmpty
              ? _sickness
              : _sicknessNote.text.trim(),
          updatedAt: now,
        ),
      ),
      null => 'Choose what to record.',
    };
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
      if (error == null) {
        _job = null;
        _tag.clear();
        _weight.clear();
        _sicknessNote.clear();
        _clearVaccines();
      }
    });
  }

  Future<String?> _saveVaccines(DateTime now) async {
    final name = _vaccineName.text.trim();
    if (name.isEmpty) {
      return 'Enter the vaccine.';
    }
    final dose = _vaccineDose.text.trim();
    if (dose.isEmpty) {
      return 'Enter the dosage.';
    }
    final tags = [for (final field in _vaccineTags) field.text.trim()];
    if (tags.any((tag) => tag.isEmpty)) {
      return 'Enter each animal tag.';
    }
    final day = _vaccineDay ?? _today;
    final note = '$name · $dose';
    for (final tag in tags) {
      final error = await widget.ledger.addHealth(
        HealthEvent(
          id: newId(),
          animalTag: tag,
          kind: HealthKind.vaccine,
          happenedOn: day,
          note: note,
          updatedAt: now,
        ),
      );
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  void _clearVaccines() {
    final extra = _vaccineTags.skip(1).toList();
    if (extra.isNotEmpty) {
      _vaccineTags.removeRange(1, _vaccineTags.length);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final field in extra) {
          field.dispose();
        }
      });
    }
    _vaccineTags.first.clear();
    _vaccineName.clear();
    _vaccineDose.clear();
    _vaccineDay = null;
  }

  Future<void> _pickVaccineDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _vaccineDay ?? _today,
      firstDate: DateTime(2000),
      lastDate: _today,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _vaccineDay = DateTime(picked.year, picked.month, picked.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.ledger,
      builder: (context, _) {
        return ListView(
          key: const Key('today-page'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              widget.localOnly
                  ? 'Saved on this phone. They sync when the farm is connected.'
                  : widget.ledger.ledger.pendingCount == 0
                  ? 'Sent to the farm server.'
                  : '${widget.ledger.ledger.pendingCount} waiting to send.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.4),
            ),
            if (widget.ledger.ledger.pendingCount > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('sync-now'),
                  onPressed: () => widget.ledger.sync(),
                  child: const Text('Sync now'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Births, deaths, weights, vaccines, and sickness.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_job == null) ...[
              _Action(
                key: const Key('record-birth'),
                label: 'Register animal',
                onTap: () => widget.onRegister(),
              ),
              _Action(
                key: const Key('record-death'),
                label: 'Death',
                onTap: () => widget.onRegister(status: AnimalStatus.dead),
              ),
              _Action(
                key: const Key('record-weight'),
                label: 'Weigh-in',
                onTap: () => setState(() => _job = _Job.weight),
              ),
              _Action(
                key: const Key('record-vaccine'),
                label: 'Vaccine',
                onTap: () => setState(() => _job = _Job.vaccine),
              ),
              _Action(
                key: const Key('record-sickness'),
                label: 'Sickness',
                onTap: () => setState(() => _job = _Job.sickness),
              ),
            ] else ...[
              Text(
                _title(_job!),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              ..._fields(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                NoticeBanner(message: _error!, isError: true),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('save-record'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
              TextButton(
                onPressed: _saving ? null : () => setState(() => _job = null),
                child: const Text('Back'),
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _fields() {
    return switch (_job) {
      _Job.weight => [
        _tagField('Animal tag', const Key('weight-tag')),
        _speciesChips('weight'),
        TextField(
          key: const Key('weight-field'),
          controller: _weight,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Weight in kg'),
        ),
      ],
      _Job.vaccine => [
        const _Label('Animals'),
        for (var index = 0; index < _vaccineTags.length; index++) ...[
          TextField(
            key: Key(index == 0 ? 'vaccine-tag' : 'vaccine-tag-$index'),
            controller: _vaccineTags[index],
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: index == 0 ? 'Animal tag' : 'Animal tag ${index + 1}',
            ),
          ),
          if (_vaccineTags.length > 1)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  final field = _vaccineTags.removeAt(index);
                  setState(() {});
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => field.dispose(),
                  );
                },
                child: const Text('Remove'),
              ),
            ),
          const SizedBox(height: 8),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('vaccine-add'),
            onPressed: _vaccineTags.length >= 12
                ? null
                : () => setState(() {
                    _vaccineTags.add(TextEditingController());
                  }),
            child: const Text('Add another animal'),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('vaccine-name'),
          controller: _vaccineName,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Vaccine'),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('vaccine-dose'),
          controller: _vaccineDose,
          decoration: const InputDecoration(labelText: 'Dosage'),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const Key('vaccine-date'),
            onPressed: _pickVaccineDay,
            child: Text(farmDateLabel(_vaccineDay ?? _today, _today)),
          ),
        ),
      ],
      _Job.sickness => [
        _tagField('Animal tag', const Key('sickness-tag')),
        const _Label('What is wrong'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final note in _sicknessNotes)
              ChoiceChip(
                label: Text(note),
                selected: _sickness == note,
                onSelected: (_) => setState(() {
                  _sickness = note;
                  _sicknessNote.text = note;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('sickness-note'),
          controller: _sicknessNote,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Sickness',
            hintText: 'What sickness the animal has',
          ),
        ),
      ],
      null => const [],
    };
  }

  Widget _tagField(String label, Key key) {
    return TextField(
      key: key,
      controller: _tag,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _speciesChips(String prefix) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('Species'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final species in FarmAccess(
              widget.role,
              herds: widget.herds,
            ).speciesChoices)
              ChoiceChip(
                key: Key('$prefix-species-${species.wire}'),
                label: Text(species.singular),
                selected: _species == species,
                onSelected: (_) => setState(() => _species = species),
              ),
          ],
        ),
      ],
    );
  }
}

String _title(_Job job) {
  return switch (job) {
    _Job.weight => 'Weigh-in',
    _Job.vaccine => 'Vaccine',
    _Job.sickness => 'Sickness',
  };
}

class _Action extends StatelessWidget {
  const _Action({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: FilledButton(onPressed: onTap, child: Text(label)),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}
