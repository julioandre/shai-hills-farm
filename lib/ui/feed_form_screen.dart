import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/ids.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';
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
  String? _formulaName;
  Species _species = Species.pig;
  String? _pen;
  String? _group;
  String? _finished;
  bool _other = false;
  String? _error;
  bool _saving = false;
  final List<String> _recipeLines = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    final formula = widget.formula;
    if (formula != null) {
      _name = formula.name;
      _recipeLines.addAll([
        for (final line in formula.lines) line.ingredientName,
      ]);
      for (final line in formula.lines) {
        _controller(line.ingredientName).text = _plain(line.quantityKg);
      }
      if (formula.minimumKg > 0) {
        _minimum.text = _plain(formula.minimumKg);
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
    for (final ingredient in _recipeLines) {
      final kilos = _amount(_controller(ingredient).text);
      if (kilos == null) {
        continue;
      }
      lines.add(FormulaLine(ingredientName: ingredient, quantityKg: kilos));
    }
    return widget.feed.saveRecipe(
      FeedFormula(
        id: widget.formula?.id ?? newId(),
        name: name,
        minimumKg: _amount(_minimum.text) ?? 0,
        lines: lines,
      ),
    );
  }

  Future<String?> _mix(DateTime today) {
    final kilos = _amount(_kg.text);
    if (kilos == null) {
      return Future.value('Enter how many kilos to mix.');
    }
    final formula = _mixFormula();
    if (formula == null) {
      return Future.value('Choose a saved recipe.');
    }
    return widget.feed.mix(
      formulaId: formula.id,
      quantityKg: kilos,
      producedOn: _day,
      producedBy: _who.text,
      today: today,
    );
  }

  FeedFormula? _mixFormula() {
    final name = _formulaName ?? '';
    if (name.isEmpty) {
      return null;
    }
    for (final row in widget.feed.mill.formulas) {
      if (row.name == name) {
        return row;
      }
    }
    return null;
  }

  Future<String?> _give(DateTime today) {
    final kilos = _amount(_kg.text);
    if (kilos == null) {
      return Future.value('Enter the kilos.');
    }
    final left = stockAfterUse(widget.feed.mill, widget.uses).mixtures
        .where((row) => row.batch.formulaName == _finished)
        .fold<double>(0, (sum, row) => sum + row.leftKg);
    if (kilos > left) {
      return Future.value(
        'Only ${formatKg(left)} is left after the feed use already recorded.',
      );
    }
    return widget.feed.giveFinished(
      id: newId(),
      formulaName: _finished ?? '',
      quantityKg: kilos,
      issuedOn: _day,
      species: _species,
      pen: _pen ?? '',
      group: _group ?? '',
      today: today,
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

  void _useTemplate(String name) {
    final template = formulaTemplates[name];
    setState(() {
      _name = name;
      if (template == null) {
        return;
      }
      _recipeLines
        ..clear()
        ..addAll([for (final line in template) line.$1]);
      for (final line in template) {
        _controller(line.$1).text = _plain(line.$2);
      }
    });
  }

  List<Widget> _recipeFields() {
    final names = _ingredientNames();
    final choices = [
      ...standardRecipes,
      if (_name != null &&
          _name!.isNotEmpty &&
          !standardRecipes.contains(_name))
        _name!,
    ];
    final preview = priceFormula(
      FeedFormula(
        id: 'preview',
        name: _name ?? '',
        lines: [
          for (final name in _recipeLines)
            if (_amount(_controller(name).text) != null)
              FormulaLine(
                ingredientName: name,
                quantityKg: _amount(_controller(name).text)!,
              ),
        ],
      ),
      widget.feed.mill,
    );
    final extras = [
      for (final name in names)
        if (!_recipeLines.contains(name)) name,
    ];
    return [
      DropdownButtonFormField<String>(
        key: const Key('recipe-name'),
        initialValue: choices.contains(_name) ? _name : null,
        isExpanded: true,
        decoration: farmDropdownDecoration('Feed'),
        items: [
          for (final name in choices)
            DropdownMenuItem(value: name, child: Text(name)),
        ],
        onChanged: (name) {
          if (name != null) {
            _useTemplate(name);
          }
        },
      ),
      const SizedBox(height: 8),
      const Text(
        'Kilos in 100 kg of this mix. The same mix can be used again.',
      ),
      const SizedBox(height: 12),
      for (final name in _recipeLines) ...[
        TextField(
          key: Key('formula-kg-$name'),
          controller: _controller(name),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '$name, kg'),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
      ],
      if (extras.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<String>(
            key: const Key('recipe-add-ingredient'),
            onSelected: (name) {
              if (_recipeLines.contains(name)) {
                return;
              }
              setState(() => _recipeLines.add(name));
            },
            itemBuilder: (context) => [
              for (final name in extras)
                PopupMenuItem(value: name, child: Text(name)),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Add ingredient'),
            ),
          ),
        ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('recipe-minimum'),
        controller: _minimum,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Warn when finished feed is below, kg',
        ),
      ),
      if (preview.totalKg > 0) ...[
        const SizedBox(height: 12),
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
    final names = [for (final row in widget.feed.mill.formulas) row.name];
    final formula = _mixFormula();
    final kilos = _amount(_kg.text);
    final plan = formula == null || kilos == null
        ? null
        : planMix(widget.feed.mill, formula, kilos);
    return [
      const Text('Pick a saved recipe and the kilos.'),
      const SizedBox(height: 12),
      if (names.isEmpty)
        const Text('Save a recipe first. Mixing uses only recipes you saved.')
      else
        DropdownButtonFormField<String>(
          key: ValueKey('mix-formula-${_formulaName ?? ''}'),
          initialValue: names.contains(_formulaName) ? _formulaName : null,
          isExpanded: true,
          decoration: farmDropdownDecoration('Feed'),
          items: [
            for (final name in names)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (name) => setState(() {
            _formulaName = name;
            if (_kg.text.trim().isEmpty && name != null) {
              final picked = _mixFormula();
              if (picked != null && picked.totalKg > 0) {
                _kg.text = _plain(picked.totalKg);
              }
            }
          }),
        ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('mix-kg'),
        controller: _kg,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Kilos to mix'),
        onChanged: (_) => setState(() {}),
      ),
      if (plan != null && plan.lines.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final line in plan.lines)
          Text(
            line.short
                ? '${line.name}: need ${formatKg(line.needKg)}, ${formatKg(line.haveKg)} on hand'
                : '${line.name}: ${formatKg(line.needKg)}',
            style: line.short
                ? Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: farmBarn)
                : null,
          ),
        if (plan.error != null) ...[
          const SizedBox(height: 8),
          Text(
            plan.error!,
            key: const Key('mix-short'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: farmBarn),
          ),
        ],
      ],
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
    final leftByName = <String, double>{};
    for (final row in ready) {
      leftByName[row.batch.formulaName] =
          (leftByName[row.batch.formulaName] ?? 0) + row.leftKg;
    }
    final names = leftByName.keys.toList()..sort();
    return [
      const Text('This comes off the finished feed.'),
      const SizedBox(height: 12),
      if (names.isEmpty)
        Text(
          widget.feed.mill.batches.isEmpty
              ? 'No mixture is left. Mix feed from the store first.'
              : 'No mixture is left after the feed use already recorded.',
        )
      else
        DropdownButtonFormField<String>(
          key: const Key('give-feed'),
          initialValue: names.contains(_finished) ? _finished : null,
          isExpanded: true,
          decoration: farmDropdownDecoration('Finished feed'),
          items: [
            for (final name in names)
              DropdownMenuItem(
                value: name,
                child: Text('$name · ${formatKg(leftByName[name] ?? 0)} left'),
              ),
          ],
          onChanged: (name) => setState(() => _finished = name),
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
