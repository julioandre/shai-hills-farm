import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/domain/validation.dart';
import 'package:shai_hills_farm/state/book_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.herd,
    required this.book,
    this.allowMoney = true,
  });

  final HerdController herd;
  final BookController book;
  final bool allowMoney;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _note = TextEditingController();
  final _amount = TextEditingController();
  BookKind? _kind;
  late DateTime _day;
  String? _animalId;
  String _animalQuery = '';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _note.dispose();
    _amount.dispose();
    super.dispose();
  }

  Animal? _animalById(String? id) {
    if (id == null) {
      return null;
    }
    for (final animal in widget.herd.animals) {
      if (animal.id == id) {
        return animal;
      }
    }
    return null;
  }

  Animal? _selectedAnimal() {
    if (_kind == BookKind.feed) {
      return null;
    }
    return _animalById(_animalId);
  }

  List<Animal> _choices() {
    final all = sortAnimals(widget.herd.animals);
    final animals = _kind == BookKind.milk
        ? [
            for (final animal in all)
              if (animal.species == Species.cattle ||
                  animal.species == Species.goat)
                animal,
          ]
        : all;
    final query = _animalQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return animals;
    }
    return [
      for (final animal in animals)
        if (animal.tag.toLowerCase().contains(query)) animal,
    ];
  }

  void _selectKind(BookKind kind) {
    setState(() {
      _kind = kind;
      if (kind == BookKind.feed) {
        _animalId = null;
      }
      if (kind == BookKind.milk) {
        final selected = _animalById(_animalId);
        final dairy =
            selected != null &&
            (selected.species == Species.cattle ||
                selected.species == Species.goat);
        if (!dairy) {
          _animalId = null;
        }
      }
      if ((kind == BookKind.sale || kind == BookKind.death) &&
          _animalId == null &&
          widget.herd.animals.length == 1) {
        _animalId = widget.herd.animals.single.id;
      }
    });
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(today) ? today : _day,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _day = DateTime(picked.year, picked.month, picked.day);
    });
  }

  Future<void> _save() async {
    final today = DateTime.now();
    final animal = _selectedAnimal();
    final message = validateEntry(
      kind: _kind,
      happenedOn: _day,
      note: _note.text,
      amountText: _amount.text,
      animal: animal,
      today: today,
    );
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    final kind = _kind!;
    setState(() {
      _saving = true;
      _error = null;
    });
    final linked = kind == BookKind.feed ? null : animal;
    final next = statusAfter(kind);
    if (linked != null && next != null && linked.status != next) {
      final herdError = await widget.herd.save(
        linked.copyWith(status: next, updatedAt: DateTime.now().toUtc()),
      );
      if (!mounted) {
        return;
      }
      if (herdError != null) {
        setState(() {
          _saving = false;
          _error = herdError;
        });
        return;
      }
    }
    final entry = FarmEntry(
      id: newId(),
      kind: kind,
      happenedOn: _day,
      animalId: linked?.id,
      animalTag: linked?.tag,
      note: noteForSave(kind, _note.text),
      amount: amountForSave(kind, _amount.text),
      updatedAt: DateTime.now().toUtc(),
    );
    final bookError = await widget.book.save(
      entry,
      today: today,
      animal: linked,
    );
    if (!mounted) {
      return;
    }
    if (bookError == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = bookError;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    final showAnimal = kind != null && kind != BookKind.feed;
    final showAmount = kind == BookKind.milk || kind == BookKind.sale;
    final needsAnimal = kind == BookKind.sale || kind == BookKind.death;
    return Scaffold(
      appBar: AppBar(title: const Text('Write in the book')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.herd,
          builder: (context, _) {
            final choices = _choices();
            final pool = _kind == BookKind.milk
                ? widget.herd.animals.where(
                    (animal) =>
                        animal.species == Species.cattle ||
                        animal.species == Species.goat,
                  )
                : widget.herd.animals;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                const _FieldLabel('What happened?'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in BookKind.values)
                      if (widget.allowMoney || item != BookKind.sale)
                        ChoiceChip(
                          key: Key('kind-${item.wire}'),
                          label: Text(item.label),
                          selected: _kind == item,
                          onSelected: (_) => _selectKind(item),
                        ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _hint(kind),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (kind != null) ...[
                  const SizedBox(height: 20),
                  const _FieldLabel('Day'),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('entry-date'),
                      onPressed: _saving ? null : _pickDay,
                      icon: const Icon(Icons.calendar_today),
                      label: Text(farmDateLabel(_day, DateTime.now())),
                    ),
                  ),
                  if (showAnimal) ...[
                    const SizedBox(height: 20),
                    const _FieldLabel('Which animal?'),
                    if (pool.isEmpty && needsAnimal)
                      const Text(
                        'Register the animal first, then come back to the book.',
                      )
                    else if (pool.isEmpty && kind == BookKind.milk)
                      const Text(
                        'No cow or goat on the register. The litres still count for the herd.',
                      )
                    else ...[
                      if (pool.length > 8) ...[
                        TextField(
                          key: const Key('find-animal'),
                          decoration: const InputDecoration(
                            hintText: 'Find a tag',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onChanged: (value) =>
                              setState(() => _animalQuery = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!needsAnimal)
                            ChoiceChip(
                              key: const Key('animal-none'),
                              label: Text(
                                kind == BookKind.milk
                                    ? 'Whole herd'
                                    : 'No specific animal',
                              ),
                              selected: _animalId == null,
                              onSelected: (_) =>
                                  setState(() => _animalId = null),
                            ),
                          for (final animal in choices)
                            ChoiceChip(
                              key: Key('animal-${animal.tag}'),
                              label: Text(animal.tag),
                              selected: _animalId == animal.id,
                              onSelected: (_) =>
                                  setState(() => _animalId = animal.id),
                            ),
                        ],
                      ),
                    ],
                  ],
                  if (showAmount) ...[
                    const SizedBox(height: 20),
                    TextField(
                      key: const Key('amount-field'),
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: kind == BookKind.milk
                            ? 'Litres'
                            : 'Cedis received',
                        hintText: kind == BookKind.milk ? '12.5' : '450',
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('note-field'),
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Note',
                      hintText: kind == BookKind.milk || kind == BookKind.sale
                          ? 'Note, if you need one'
                          : 'Short note',
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  NoticeBanner(
                    key: const Key('entry-error'),
                    message: _error!,
                    isError: true,
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const Key('save-entry'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save note'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _hint(BookKind? kind) {
  return switch (kind) {
    BookKind.health => 'For example: dewormed, or not eating.',
    BookKind.feed => 'For example: maize bran for the pigs.',
    BookKind.breeding =>
      'Who was mated or born. Add a new animal on the Animals page.',
    BookKind.milk => 'Litres from the cattle or goats.',
    BookKind.sale =>
      'The animal leaves the herd counts. Write the cedis you received.',
    BookKind.death => 'The animal leaves the herd counts. Write what you know.',
    null => 'Pick one. A short note is enough.',
  };
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
