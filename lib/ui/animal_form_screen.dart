import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class AnimalFormScreen extends StatefulWidget {
  const AnimalFormScreen({super.key, required this.herd, this.animal});

  final HerdController herd;
  final Animal? animal;

  @override
  State<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends State<AnimalFormScreen> {
  late final TextEditingController _tag;
  Species? _species;
  Sex? _sex;
  late AnimalStatus _status;
  String? _error;
  bool _saving = false;

  bool get _editing => widget.animal != null;

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    _tag = TextEditingController(text: animal?.tag ?? '');
    _species = animal?.species;
    _sex = animal?.sex;
    _status = animal?.status ?? AnimalStatus.onFarm;
  }

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final animal = Animal(
      id: widget.animal?.id ?? newId(),
      tag: _tag.text.trim(),
      species: _species ?? Species.pig,
      sex: _sex ?? Sex.female,
      status: _status,
      updatedAt: DateTime.now().toUtc(),
    );
    if (_species == null || _sex == null) {
      final missing = _species == null
          ? 'Choose a species.'
          : 'Choose female or male.';
      setState(() {
        _saving = false;
        _error = missing;
      });
      return;
    }
    final error = await widget.herd.save(animal);
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
            'To keep the history, set the status to Sold or Dead instead.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit animal' : 'Register animal')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
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
                for (final species in Species.values)
                  ChoiceChip(
                    key: Key('species-${species.wire}'),
                    label: Text(species.singular),
                    selected: _species == species,
                    onSelected: (_) => setState(() => _species = species),
                  ),
              ],
            ),
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
            const SizedBox(height: 8),
            Text(
              'On farm animals are included in the herd counts. '
              'Sold and dead stay on the register.',
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
