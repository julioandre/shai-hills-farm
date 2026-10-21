import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

enum FeedTask { buy, recipe, mix, give }

/// Buy stock, save a recipe, mix a batch, or give feed to a pen.
class FeedFormScreen extends StatefulWidget {
  const FeedFormScreen({
    super.key,
    required this.feed,
    required this.task,
    required this.showMoney,
    this.formula,
    this.uses = const [],
    this.speciesChoices = const [],
  });

  final FeedController feed;
  final FeedTask task;
  final bool showMoney;
  final FeedFormula? formula;
  final List<FeedUse> uses;
  final List<Species> speciesChoices;

  @override
  State<FeedFormScreen> createState() => _FeedFormScreenState();
}

class _FeedFormScreenState extends State<FeedFormScreen> {
  final _kg = TextEditingController();
  final _cost = TextEditingController();
  final _supplier = TextEditingController();
  final _minimum = TextEditingController();
  final _custom = TextEditingController();
  final _who = TextEditingController();
  final _lineKg = <String, TextEditingController>{};
  late DateTime _day;
  String? _name;
  String? _formulaId;
  String? _batchId;
  Species _species = Species.pig;
  String? _pen;
  String? _group;
  bool _other = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    final formula = widget.formula;
    if (formula != null) {
      _name = formula.name;
      for (final line in formula.lines) {
        _controller(line.ingredientName).text = _plain(line.quantityKg);
      }
    }
    final choices = widget.speciesChoices;
    if (choices.isNotEmpty && !choices.contains(_species)) {
      _species = choices.first;
    }
    final names = _ingredientNames();
    if (widget.task == FeedTask.buy && names.isNotEmpty) {
      _name = names.first;
    }
  }

  @override
  void dispose() {
    _kg.dispose();
    _cost.dispose();
    _supplier.dispose();
    _minimum.dispose();
    _custom.dispose();
    _who.dispose();
    for (final controller in _lineKg.values) {
      controller.dispose();
    }
    super.dispose();
  }

  List<String> _ingredientNames() {
    final names = <String>{
      ...standardIngredients,
      for (final row in widget.feed.mill.ingredients) row.name,
    };
    final sorted = names.toList()..sort();
    return sorted;
  }

  TextEditingController _controller(String name) {
    return _lineKg.putIfAbsent(name, TextEditingController.new);
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
    setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final today = DateTime.now();
    final error = switch (widget.task) {
      FeedTask.buy => await _buy(today),
      FeedTask.recipe => await _recipe(),
      FeedTask.mix => await _mix(today),
      FeedTask.give => await _give(today),
    };
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

  Future<String?> _buy(DateTime today) async {
    final name = _other ? _custom.text.trim() : (_name ?? '');
    final kilos = _amount(_kg.text);
    if (kilos == null) {
      return 'Enter the kilos.';
    }
    final cost = widget.showMoney ? double.tryParse(_cost.text.trim()) : 0.0;
    if (widget.showMoney && (cost == null || cost < 0)) {
      return 'Enter the cost per kg.';
    }
    return widget.feed.buy(
      FeedIngredient(
        id: newId(),
        name: name,
        stockKg: kilos,
        unitCost: cost ?? 0,
        supplier: _supplier.text,
        purchasedOn: _day,
        minimumKg: _amount(_minimum.text) ?? 0,
      ),
      today,
    );
  }

  Future<String?> _recipe() async {
    final name = _name ?? '';
    final lines = <FormulaLine>[];
    for (final ingredient in _ingredientNames()) {
      final kilos = _amount(_controller(ingredient).text);
      if (kilos == null) {
        continue;
      }
      lines.add(FormulaLine(ingredientName: ingredient, quantityKg: kilos));
    }
    return widget.feed.saveRecipe(
      FeedFormula(id: widget.formula?.id ?? newId(), name: name, lines: lines),
    );
  }

  Future<String?> _mix(DateTime today) {
    final kilos = _amount(_kg.text);
    if (kilos == null) {
      return Future.value('Enter how many kilos to mix.');
    }
    return widget.feed.mix(
      formulaId: _formulaId ?? '',
      quantityKg: kilos,
      producedOn: _day,
      producedBy: _who.text,
      today: today,
    );
  }

  Future<String?> _give(DateTime today) {
    final kilos = _amount(_kg.text);
    if (kilos == null) {
      return Future.value('Enter the kilos.');
    }
    final left = stockAfterUse(widget.feed.mill, widget.uses).mixtures
        .where((row) => row.batch.id == _batchId)
        .fold<double>(0, (sum, row) => sum + row.leftKg);
    if (kilos > left) {
      return Future.value(
        'Only ${formatKg(left)} is left after the feed use already recorded.',
      );
    }
    return widget.feed.give(
      FeedIssue(
        id: newId(),
        batchId: _batchId ?? '',
        issuedOn: _day,
        species: _species,
        pen: _pen ?? '',
        group: _group ?? '',
        quantityKg: kilos,
      ),
      today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.task) {
      FeedTask.buy => 'Buy ingredient',
      FeedTask.recipe => 'Recipe',
      FeedTask.mix => 'Mix a batch',
      FeedTask.give => 'Give feed out',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        key: const Key('feed-form'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            NoticeBanner(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          ...switch (widget.task) {
            FeedTask.buy => _buyFields(),
            FeedTask.recipe => _recipeFields(),
            FeedTask.mix => _mixFields(),
            FeedTask.give => _giveFields(),
          },
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('save-feed'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buyFields() {
    final names = _ingredientNames();
    return [
      const Text('Ingredient'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in names)
            ChoiceChip(
              key: Key('ingredient-$name'),
              label: Text(name),
              selected: !_other && _name == name,
              onSelected: (_) => setState(() {
                _other = false;
                _name = name;
              }),
            ),
          ChoiceChip(
            key: const Key('ingredient-other'),
            label: const Text('Other'),
            selected: _other,
            onSelected: (_) => setState(() => _other = true),
          ),
        ],
      ),
      if (_other) ...[
        const SizedBox(height: 12),
        TextField(
          key: const Key('ingredient-custom'),
          controller: _custom,
          decoration: const InputDecoration(hintText: 'Ingredient name'),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        key: const Key('ingredient-kg'),
        controller: _kg,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: 'Kilos bought'),
      ),
      if (widget.showMoney) ...[
        const SizedBox(height: 12),
        TextField(
          key: const Key('ingredient-cost'),
          controller: _cost,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: 'Cost per kg, in cedis'),
        ),
      ],
      const SizedBox(height: 12),
      TextField(
        key: const Key('ingredient-supplier'),
        controller: _supplier,
        decoration: const InputDecoration(hintText: 'Supplier'),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('ingredient-minimum'),
        controller: _minimum,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          hintText: 'Warn me below this many kg',
        ),
      ),
      const SizedBox(height: 12),
      _DateButton(day: _day, onPressed: _pickDay),
    ];
  }

  List<Widget> _recipeFields() {
    final names = _ingredientNames();
    final selected = _name;
    final preview = selected == null
        ? null
        : priceFormula(
            FeedFormula(
              id: 'preview',
              name: selected,
              lines: [
                for (final name in names)
                  if (_amount(_controller(name).text) != null)
                    FormulaLine(
                      ingredientName: name,
                      quantityKg: _amount(_controller(name).text)!,
                    ),
              ],
            ),
            widget.feed.mill,
          );
    return [
      const Text('Feed'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in standardRecipes)
            ChoiceChip(
              label: Text(name),
              selected: _name == name,
              onSelected: (_) => setState(() => _name = name),
            ),
        ],
      ),
      const SizedBox(height: 16),
      const Text('Kilos in the recipe'),
      const SizedBox(height: 8),
      for (final name in names) ...[
        TextField(
          key: Key('formula-kg-$name'),
          controller: _controller(name),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(hintText: '$name, kg'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
      ],
      if (preview != null && preview.totalKg > 0) ...[
        const SizedBox(height: 8),
        Text(
          widget.showMoney
              ? '${formatKg(preview.totalKg)}. ${formatCedis(preview.totalCost)} in total. ${formatCedis(preview.costPerKg)} per kg.'
              : '${formatKg(preview.totalKg)} in this recipe.',
          key: const Key('formula-preview'),
        ),
      ],
    ];
  }

  List<Widget> _mixFields() {
    final formulas = widget.feed.mill.formulas;
    return [
      const Text('Mixing takes the ingredients out of the store.'),
      const SizedBox(height: 12),
      const Text('Which feed?'),
      const SizedBox(height: 8),
      if (formulas.isEmpty)
        const Text('Save a recipe first.')
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final formula in formulas)
              ChoiceChip(
                key: Key('mix-${formula.id}'),
                label: Text(formula.name),
                selected: _formulaId == formula.id,
                onSelected: (_) => setState(() {
                  _formulaId = formula.id;
                  if (_kg.text.trim().isEmpty) {
                    _kg.text = _plain(formula.totalKg);
                  }
                }),
              ),
          ],
        ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('mix-kg'),
        controller: _kg,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: 'Kilos to mix'),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('mix-who'),
        controller: _who,
        decoration: const InputDecoration(hintText: 'Who mixed it?'),
      ),
      const SizedBox(height: 12),
      _DateButton(day: _day, onPressed: _pickDay),
    ];
  }

  List<Widget> _giveFields() {
    final ready = stockAfterUse(widget.feed.mill, widget.uses).mixtures;
    return [
      const Text('Which mixture is still in the store?'),
      const SizedBox(height: 8),
      if (ready.isEmpty)
        Text(
          widget.feed.mill.batches.isEmpty
              ? 'No mixture is left. Mix feed from the store first.'
              : 'No mixture is left after the feed use already recorded.',
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final row in ready)
              ChoiceChip(
                key: Key('give-${row.batch.id}'),
                label: Text(
                  '${row.batch.number} · ${formatKg(row.leftKg)} left',
                ),
                selected: _batchId == row.batch.id,
                onSelected: (_) => setState(() => _batchId = row.batch.id),
              ),
          ],
        ),
      const SizedBox(height: 12),
      const Text('Animals'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final species
              in widget.speciesChoices.isEmpty
                  ? Species.values
                  : widget.speciesChoices)
            ChoiceChip(
              label: Text(species.plural),
              selected: _species == species,
              onSelected: (_) => setState(() => _species = species),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Pen'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final pen in standardPens)
            ChoiceChip(
              label: Text(pen),
              selected: _pen == pen,
              onSelected: (_) => setState(() => _pen = pen),
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Text('Group'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final group in standardGroups)
            ChoiceChip(
              label: Text(group),
              selected: _group == group,
              onSelected: (_) => setState(() => _group = group),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('give-kg'),
        controller: _kg,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(hintText: 'Kilos given out'),
      ),
      const SizedBox(height: 12),
      _DateButton(day: _day, onPressed: _pickDay),
    ];
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.day, required this.onPressed});

  final DateTime day;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton(
        onPressed: onPressed,
        child: Text(formatFarmDate(day)),
      ),
    );
  }
}

double? _amount(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', ''));
  if (value == null || value < 0) {
    return null;
  }
  if (value == 0) {
    return null;
  }
  return value;
}

String _plain(double kg) {
  if (kg == kg.roundToDouble()) {
    return kg.toInt().toString();
  }
  return kg.toString();
}
