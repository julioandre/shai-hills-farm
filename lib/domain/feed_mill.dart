import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/ledger.dart';

/// Ingredients the mill keeps in stock. A farm can add its own names too.
const standardIngredients = [
  'Maize',
  'Soybean Meal',
  'Fish Meal',
  'Wheat Bran',
  'Palm Kernel Cake',
  'Premix',
  'Salt',
  'Limestone',
  'Hay',
  'Napier Grass',
];

/// Recipe names the mill can mix again.
const standardRecipes = [
  'Pig Starter',
  'Pig Grower',
  'Pig Finisher',
  'Sow Feed',
  'Gestating Sow Feed',
  'Lactating Sow Feed',
  'Boar Feed',
  'Broiler Starter',
  'Broiler Grower',
  'Broiler Finisher',
  'Layer Feed',
  'Layer Mash',
  'Dairy Feed',
  'Dairy Concentrate',
  'Beef Feed',
  'Goat Feed',
  'Sheep Feed',
];

/// Kilos of each ingredient in 100 kg of a reusable mix.
const formulaTemplates = <String, List<(String, double)>>{
  'Pig Starter': [
    ('Maize', 50),
    ('Soybean Meal', 25),
    ('Fish Meal', 8),
    ('Wheat Bran', 12),
    ('Premix', 3),
    ('Salt', 2),
  ],
  'Pig Grower': [
    ('Maize', 55),
    ('Soybean Meal', 20),
    ('Palm Kernel Cake', 15),
    ('Wheat Bran', 5),
    ('Premix', 3),
    ('Salt', 2),
  ],
  'Pig Finisher': [
    ('Maize', 60),
    ('Soybean Meal', 15),
    ('Palm Kernel Cake', 15),
    ('Wheat Bran', 6),
    ('Premix', 2),
    ('Salt', 2),
  ],
  'Sow Feed': [
    ('Maize', 48),
    ('Wheat Bran', 22),
    ('Palm Kernel Cake', 16),
    ('Soybean Meal', 10),
    ('Premix', 2),
    ('Salt', 2),
  ],
  'Gestating Sow Feed': [
    ('Maize', 45),
    ('Wheat Bran', 25),
    ('Palm Kernel Cake', 18),
    ('Soybean Meal', 8),
    ('Premix', 2),
    ('Salt', 2),
  ],
  'Lactating Sow Feed': [
    ('Maize', 50),
    ('Soybean Meal', 22),
    ('Wheat Bran', 15),
    ('Fish Meal', 5),
    ('Palm Kernel Cake', 5),
    ('Premix', 2),
    ('Salt', 1),
  ],
  'Boar Feed': [
    ('Maize', 55),
    ('Wheat Bran', 20),
    ('Palm Kernel Cake', 15),
    ('Soybean Meal', 6),
    ('Premix', 2),
    ('Salt', 2),
  ],
  'Broiler Starter': [
    ('Maize', 50),
    ('Soybean Meal', 30),
    ('Fish Meal', 10),
    ('Wheat Bran', 6),
    ('Premix', 3),
    ('Salt', 1),
  ],
  'Broiler Grower': [
    ('Maize', 55),
    ('Soybean Meal', 25),
    ('Fish Meal', 6),
    ('Wheat Bran', 10),
    ('Premix', 3),
    ('Salt', 1),
  ],
  'Broiler Finisher': [
    ('Maize', 60),
    ('Soybean Meal', 22),
    ('Fish Meal', 4),
    ('Wheat Bran', 10),
    ('Premix', 3),
    ('Salt', 1),
  ],
  'Layer Feed': [
    ('Maize', 50),
    ('Soybean Meal', 22),
    ('Wheat Bran', 15),
    ('Limestone', 8),
    ('Palm Kernel Cake', 3),
    ('Premix', 1.5),
    ('Salt', 0.5),
  ],
  'Layer Mash': [
    ('Maize', 50),
    ('Soybean Meal', 20),
    ('Wheat Bran', 12),
    ('Limestone', 8),
    ('Palm Kernel Cake', 6),
    ('Premix', 3),
    ('Salt', 1),
  ],
  'Dairy Feed': [
    ('Maize', 50),
    ('Wheat Bran', 30),
    ('Palm Kernel Cake', 15),
    ('Soybean Meal', 4),
    ('Salt', 1),
  ],
  'Dairy Concentrate': [
    ('Maize', 40),
    ('Wheat Bran', 25),
    ('Palm Kernel Cake', 20),
    ('Soybean Meal', 10),
    ('Premix', 3),
    ('Salt', 2),
  ],
  'Beef Feed': [
    ('Maize', 45),
    ('Wheat Bran', 25),
    ('Palm Kernel Cake', 20),
    ('Soybean Meal', 6),
    ('Premix', 2),
    ('Salt', 2),
  ],
  'Goat Feed': [
    ('Maize', 40),
    ('Wheat Bran', 25),
    ('Palm Kernel Cake', 20),
    ('Hay', 10),
    ('Premix', 3),
    ('Salt', 2),
  ],
  'Sheep Feed': [
    ('Maize', 40),
    ('Wheat Bran', 25),
    ('Palm Kernel Cake', 18),
    ('Hay', 12),
    ('Premix', 3),
    ('Salt', 2),
  ],
};

const standardPens = [
  'Grower Pen A',
  'Sow House',
  'Boar Unit',
  'Dairy Unit',
  'Broiler House',
  'Layer House',
];

const standardGroups = [
  'Growers',
  'Sows',
  'Boars',
  'Broilers',
  'Layers',
  'Dairy',
  'Beef',
];

/// Which animals a mix was made for. Dairy and beef are both cattle.
enum FeedBucket {
  pigs('Pigs'),
  broilers('Broilers'),
  layers('Layers'),
  dairy('Dairy'),
  beef('Beef'),
  other('Other');

  const FeedBucket(this.label);

  final String label;

  bool get usesWeight =>
      this == FeedBucket.pigs ||
      this == FeedBucket.broilers ||
      this == FeedBucket.layers;
}

/// One raw ingredient currently in the store.
class FeedIngredient {
  const FeedIngredient({
    required this.id,
    required this.name,
    required this.stockKg,
    required this.unitCost,
    required this.supplier,
    required this.purchasedOn,
    required this.minimumKg,
    this.group = '',
  });

  final String id;
  final String name;
  final double stockKg;
  final double unitCost;
  final String supplier;
  final DateTime purchasedOn;
  final double minimumKg;

  /// Energy source, Forage, Additives, Cerelac, or Other. Empty on older rows.
  final String group;

  bool get low => stockKg <= 0 || (minimumKg > 0 && stockKg <= minimumKg);

  FeedIngredient copyWith({double? stockKg, double? unitCost, String? group}) {
    return FeedIngredient(
      id: id,
      name: name,
      stockKg: stockKg ?? this.stockKg,
      unitCost: unitCost ?? this.unitCost,
      supplier: supplier,
      purchasedOn: purchasedOn,
      minimumKg: minimumKg,
      group: group ?? this.group,
    );
  }

  factory FeedIngredient.fromJson(Map<String, dynamic> json) {
    return FeedIngredient(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      stockKg: _double(json['stockKg']),
      unitCost: _double(json['unitCost']),
      supplier: _string(json, 'supplier'),
      purchasedOn: _date(json['purchasedOn']),
      minimumKg: _double(json['minimumKg']),
      group: _string(json, 'group'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'stockKg': stockKg,
      'unitCost': unitCost,
      'supplier': supplier,
      'purchasedOn': formatIsoDate(purchasedOn),
      'minimumKg': minimumKg,
      'group': group,
    };
  }
}

/// Kilos of one ingredient in a recipe, as written.
class FormulaLine {
  const FormulaLine({required this.ingredientName, required this.quantityKg});

  final String ingredientName;
  final double quantityKg;

  factory FormulaLine.fromJson(Map<String, dynamic> json) {
    return FormulaLine(
      ingredientName: _string(json, 'ingredientName'),
      quantityKg: _double(json['quantityKg']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'ingredientName': ingredientName, 'quantityKg': quantityKg};
  }
}

/// A mix the farm can make again.
class FeedFormula {
  const FeedFormula({
    required this.id,
    required this.name,
    required this.lines,
    this.minimumKg = 0,
  });

  final String id;
  final String name;
  final List<FormulaLine> lines;

  /// Warn when finished feed of this mix falls to this many kilos.
  final double minimumKg;

  double get totalKg =>
      lines.fold<double>(0, (sum, line) => sum + line.quantityKg);

  factory FeedFormula.fromJson(Map<String, dynamic> json) {
    return FeedFormula(
      id: _string(json, 'id'),
      name: _string(json, 'name'),
      lines: [
        for (final row in _maps(json['lines'])) FormulaLine.fromJson(row),
      ],
      minimumKg: _double(json['minimumKg']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lines': [for (final line in lines) line.toJson()],
      'minimumKg': minimumKg,
    };
  }
}

/// What one ingredient cost inside a recipe.
class FormulaShare {
  const FormulaShare({
    required this.name,
    required this.kg,
    required this.percent,
    required this.cost,
  });

  final String name;
  final double kg;

  /// Share of the recipe, from 0 to 1.
  final double percent;
  final double cost;
}

/// Total cost of a recipe at the prices now in the store.
class FormulaCost {
  const FormulaCost({
    required this.totalKg,
    required this.totalCost,
    required this.costPerKg,
    required this.lines,
  });

  final double totalKg;
  final double totalCost;
  final double costPerKg;
  final List<FormulaShare> lines;
}

/// Ingredient kilos actually poured into one batch, at that day's price.
class BatchLine {
  const BatchLine({
    required this.ingredientName,
    required this.quantityKg,
    required this.unitCost,
  });

  final String ingredientName;
  final double quantityKg;
  final double unitCost;

  double get cost => quantityKg * unitCost;

  factory BatchLine.fromJson(Map<String, dynamic> json) {
    return BatchLine(
      ingredientName: _string(json, 'ingredientName'),
      quantityKg: _double(json['quantityKg']),
      unitCost: _double(json['unitCost']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredientName': ingredientName,
      'quantityKg': quantityKg,
      'unitCost': unitCost,
    };
  }
}

/// One time the mill mixed a recipe.
class FeedBatch {
  const FeedBatch({
    required this.id,
    required this.number,
    required this.formulaName,
    required this.producedOn,
    required this.quantityKg,
    required this.lines,
    required this.producedBy,
  });

  final String id;
  final String number;
  final String formulaName;
  final DateTime producedOn;
  final double quantityKg;
  final List<BatchLine> lines;
  final String producedBy;

  double get cost => lines.fold<double>(0, (sum, line) => sum + line.cost);

  double get costPerKg => quantityKg <= 0 ? 0 : cost / quantityKg;

  factory FeedBatch.fromJson(Map<String, dynamic> json) {
    return FeedBatch(
      id: _string(json, 'id'),
      number: _string(json, 'number'),
      formulaName: _string(json, 'formulaName'),
      producedOn: _date(json['producedOn']),
      quantityKg: _double(json['quantityKg']),
      lines: [for (final row in _maps(json['lines'])) BatchLine.fromJson(row)],
      producedBy: _string(json, 'producedBy'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'formulaName': formulaName,
      'producedOn': formatIsoDate(producedOn),
      'quantityKg': quantityKg,
      'lines': [for (final line in lines) line.toJson()],
      'producedBy': producedBy,
    };
  }
}

/// Feed carried from a batch to a pen.
class FeedIssue {
  const FeedIssue({
    required this.id,
    required this.batchId,
    required this.issuedOn,
    required this.species,
    required this.pen,
    required this.group,
    required this.quantityKg,
  });

  final String id;
  final String batchId;
  final DateTime issuedOn;
  final Species species;
  final String pen;
  final String group;
  final double quantityKg;

  factory FeedIssue.fromJson(Map<String, dynamic> json) {
    return FeedIssue(
      id: _string(json, 'id'),
      batchId: _string(json, 'batchId'),
      issuedOn: _date(json['issuedOn']),
      species: Species.parse(_string(json, 'species')),
      pen: _string(json, 'pen'),
      group: _string(json, 'group'),
      quantityKg: _double(json['quantityKg']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchId': batchId,
      'issuedOn': formatIsoDate(issuedOn),
      'species': species.wire,
      'pen': pen,
      'group': group,
      'quantityKg': quantityKg,
    };
  }
}

/// Ingredients, recipes, mixes, and what was given out.
class FeedMill {
  const FeedMill({
    this.ingredients = const [],
    this.formulas = const [],
    this.batches = const [],
    this.issues = const [],
  });

  static const empty = FeedMill();

  final List<FeedIngredient> ingredients;
  final List<FeedFormula> formulas;
  final List<FeedBatch> batches;
  final List<FeedIssue> issues;

  factory FeedMill.fromJson(Map<String, dynamic> json) {
    return FeedMill(
      ingredients: [
        for (final row in _maps(json['ingredients']))
          FeedIngredient.fromJson(row),
      ],
      formulas: [
        for (final row in _maps(json['formulas'])) FeedFormula.fromJson(row),
      ],
      batches: [
        for (final row in _maps(json['batches'])) FeedBatch.fromJson(row),
      ],
      issues: [
        for (final row in _maps(json['issues'])) FeedIssue.fromJson(row),
      ],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ingredients': [for (final row in ingredients) row.toJson()],
      'formulas': [for (final row in formulas) row.toJson()],
      'batches': [for (final row in batches) row.toJson()],
      'issues': [for (final row in issues) row.toJson()],
    };
  }
}

/// A change that either saved or explains why it did not.
class FeedChange {
  const FeedChange({required this.mill, this.error});

  final FeedMill mill;
  final String? error;

  bool get ok => error == null;
}

/// Kilos of feed given to one kind of animal, group, or pen.
class FeedSlice {
  const FeedSlice(this.label, this.kg, {this.species});

  final String label;
  final double kg;
  final Species? species;
}

/// One month of mixing, giving out, and cost.
class FeedPoint {
  const FeedPoint({
    required this.label,
    required this.producedKg,
    required this.issuedKg,
    required this.cost,
  });

  final String label;
  final double producedKg;
  final double issuedKg;
  final double cost;
}

/// How well one kind of animal turned feed into gain or milk.
class FeedScore {
  const FeedScore({
    required this.name,
    required this.feedKg,
    required this.gainKg,
    required this.litres,
    required this.cost,
    required this.perLitre,
    this.fcr,
  });

  final String name;
  final double feedKg;
  final double gainKg;
  final double litres;
  final double cost;
  final bool perLitre;
  final double? fcr;

  double? get costPerResult {
    final basis = perLitre ? litres : gainKg;
    if (basis <= 0 || cost <= 0) {
      return null;
    }
    return cost / basis;
  }
}

/// A pen that can be compared with the others.
class PenScore {
  const PenScore({
    required this.pen,
    required this.kind,
    required this.feedKg,
    this.fcr,
  });

  final String pen;
  final String kind;
  final double feedKg;
  final double? fcr;
}

/// Feed cost next to sales for one enterprise.
class FeedMoneyLine {
  const FeedMoneyLine({
    required this.enterprise,
    required this.feedCost,
    required this.sales,
  });

  final String enterprise;
  final double feedCost;
  final double sales;
}

class FeedReport {
  const FeedReport({
    required this.scores,
    required this.pens,
    required this.money,
    this.best,
    this.worst,
  });

  final List<FeedScore> scores;
  final List<PenScore> pens;
  final List<FeedMoneyLine> money;
  final PenScore? best;
  final PenScore? worst;
}

String formatKg(double kg) {
  final tenths = (kg * 10).round();
  final whole = tenths ~/ 10;
  final fraction = tenths.abs() % 10;
  if (fraction == 0) {
    return '$whole kg';
  }
  return '$whole.$fraction kg';
}

String formatPercent(double share) {
  final pct = share * 100;
  if ((pct - pct.round()).abs() < 0.05) {
    return '${pct.round()}%';
  }
  return '${pct.toStringAsFixed(1)}%';
}

List<FeedIngredient> lowStock(FeedMill mill) {
  final rows = [
    for (final row in mill.ingredients)
      if (row.low) row,
  ];
  rows.sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

FormulaCost priceFormula(FeedFormula formula, FeedMill mill) {
  final totalKg = formula.totalKg;
  final shares = <FormulaShare>[];
  var totalCost = 0.0;
  for (final line in formula.lines) {
    if (line.quantityKg <= 0) {
      continue;
    }
    final cost = line.quantityKg * _unitCost(mill, line.ingredientName);
    totalCost += cost;
    shares.add(
      FormulaShare(
        name: line.ingredientName,
        kg: line.quantityKg,
        percent: totalKg <= 0 ? 0 : line.quantityKg / totalKg,
        cost: cost,
      ),
    );
  }
  return FormulaCost(
    totalKg: totalKg,
    totalCost: totalCost,
    costPerKg: totalKg <= 0 ? 0 : totalCost / totalKg,
    lines: shares,
  );
}

/// A mixed batch that still has kilos to give out.
class MixtureStock {
  const MixtureStock({required this.batch, required this.leftKg});

  final FeedBatch batch;
  final double leftKg;
}

/// Mixtures still in the store, largest amount first.
List<MixtureStock> mixturesOnHand(FeedMill mill) {
  final rows = <MixtureStock>[
    for (final batch in mill.batches)
      if (remainingKg(mill, batch.id) > 0)
        MixtureStock(batch: batch, leftKg: remainingKg(mill, batch.id)),
  ];
  rows.sort((a, b) => b.leftKg.compareTo(a.leftKg));
  return rows;
}

/// One ingredient after recorded feed use has been taken off.
class IngredientOnHand {
  const IngredientOnHand({
    required this.ingredient,
    required this.leftKg,
    required this.usedKg,
  });

  final FeedIngredient ingredient;
  final double leftKg;
  final double usedKg;

  bool get low =>
      leftKg <= 0 ||
      (ingredient.minimumKg > 0 && leftKg <= ingredient.minimumKg);
}

/// What is still in the store once ledger feed use has been applied.
class StoreStock {
  const StoreStock({
    required this.ingredients,
    required this.mixtures,
    required this.shortKg,
  });

  final List<IngredientOnHand> ingredients;
  final List<MixtureStock> mixtures;

  /// Recorded use that the store could not cover.
  final double shortKg;
}

/// Kilos still here: bought and mixed stock, minus feed use recorded on the farm.
///
/// A use named like an ingredient or a recipe comes off that stock.
/// A use that names neither stays as a shortfall and does not empty a mixture.
StoreStock stockAfterUse(FeedMill mill, List<FeedUse> uses) {
  final ingredientLeft = {
    for (final row in mill.ingredients) row.id: row.stockKg,
  };
  final ingredientUsed = {for (final row in mill.ingredients) row.id: 0.0};
  final batchLeft = {
    for (final batch in mill.batches) batch.id: remainingKg(mill, batch.id),
  };
  final batches = [...mill.batches]
    ..sort((a, b) {
      final byDay = a.producedOn.compareTo(b.producedOn);
      if (byDay != 0) {
        return byDay;
      }
      return a.number.compareTo(b.number);
    });
  final orderedUses = [...uses]
    ..sort((a, b) {
      final byDay = a.happenedOn.compareTo(b.happenedOn);
      if (byDay != 0) {
        return byDay;
      }
      return a.id.compareTo(b.id);
    });
  var short = 0.0;
  for (final use in orderedUses) {
    var need = use.quantityKg < 0 ? 0.0 : use.quantityKg;
    final name = use.feedType.trim().toLowerCase();
    if (name.isNotEmpty) {
      for (final row in mill.ingredients) {
        if (need <= 0) {
          break;
        }
        if (row.name.trim().toLowerCase() != name) {
          continue;
        }
        final taken = _draw(ingredientLeft, row.id, need);
        ingredientUsed[row.id] = (ingredientUsed[row.id] ?? 0) + taken;
        need = _roundKg(need - taken);
      }
      for (final batch in batches) {
        if (need <= 0) {
          break;
        }
        if (batch.formulaName.trim().toLowerCase() != name) {
          continue;
        }
        need = _roundKg(need - _draw(batchLeft, batch.id, need));
      }
    }
    short += need;
  }
  final ingredients = [
    for (final row in mill.ingredients)
      IngredientOnHand(
        ingredient: row,
        leftKg: ingredientLeft[row.id] ?? 0,
        usedKg: ingredientUsed[row.id] ?? 0,
      ),
  ]..sort((a, b) => a.ingredient.name.compareTo(b.ingredient.name));
  final mixtures = [
    for (final batch in mill.batches)
      if ((batchLeft[batch.id] ?? 0) > 0)
        MixtureStock(batch: batch, leftKg: batchLeft[batch.id]!),
  ]..sort((a, b) => b.leftKg.compareTo(a.leftKg));
  return StoreStock(
    ingredients: ingredients,
    mixtures: mixtures,
    shortKg: _roundKg(short),
  );
}

double _draw(Map<String, double> left, String id, double need) {
  final have = left[id] ?? 0;
  if (have <= 0 || need <= 0) {
    return 0;
  }
  final taken = need < have ? need : have;
  left[id] = _roundKg(have - taken);
  return taken;
}

double remainingKg(FeedMill mill, String batchId) {
  FeedBatch? batch;
  for (final row in mill.batches) {
    if (row.id == batchId) {
      batch = row;
    }
  }
  if (batch == null) {
    return 0;
  }
  var issued = 0.0;
  for (final issue in mill.issues) {
    if (issue.batchId == batchId) {
      issued += issue.quantityKg;
    }
  }
  final left = batch.quantityKg - issued;
  return left < 0 ? 0 : _roundKg(left);
}

FeedChange buyIngredient(
  FeedMill mill,
  FeedIngredient incoming,
  DateTime today,
) {
  final name = incoming.name.trim();
  if (name.isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the ingredient.');
  }
  if (incoming.stockKg <= 0) {
    return FeedChange(mill: mill, error: 'Enter the kilos.');
  }
  if (incoming.unitCost < 0) {
    return FeedChange(mill: mill, error: 'Enter the cost per kg.');
  }
  final ahead = _ahead(incoming.purchasedOn, today);
  if (ahead != null) {
    return FeedChange(mill: mill, error: ahead);
  }
  final supplier = incoming.supplier.trim().isEmpty
      ? 'Not written'
      : incoming.supplier.trim();
  final minimum = incoming.minimumKg < 0 ? 0.0 : incoming.minimumKg;
  final existing = _ingredient(mill, name);
  final group = incoming.group.trim().isNotEmpty
      ? incoming.group.trim()
      : (existing?.group ?? '');
  if (existing == null) {
    return FeedChange(
      mill: FeedMill(
        ingredients: [
          ...mill.ingredients,
          FeedIngredient(
            id: incoming.id,
            name: name,
            stockKg: _roundKg(incoming.stockKg),
            unitCost: incoming.unitCost,
            supplier: supplier,
            purchasedOn: _day(incoming.purchasedOn),
            minimumKg: minimum,
            group: group,
          ),
        ],
        formulas: mill.formulas,
        batches: mill.batches,
        issues: mill.issues,
      ),
    );
  }
  return FeedChange(
    mill: FeedMill(
      ingredients: [
        for (final row in mill.ingredients)
          if (row.id == existing.id)
            FeedIngredient(
              id: existing.id,
              name: existing.name,
              stockKg: _roundKg(existing.stockKg + incoming.stockKg),
              unitCost: incoming.unitCost,
              supplier: supplier,
              purchasedOn: _day(incoming.purchasedOn),
              minimumKg: minimum,
              group: group,
            )
          else
            row,
      ],
      formulas: mill.formulas,
      batches: mill.batches,
      issues: mill.issues,
    ),
  );
}

FeedChange saveFormula(FeedMill mill, FeedFormula formula) {
  final name = formula.name.trim();
  if (name.isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the feed.');
  }
  final lines = [
    for (final line in formula.lines)
      if (line.ingredientName.trim().isNotEmpty && line.quantityKg > 0)
        FormulaLine(
          ingredientName: line.ingredientName.trim(),
          quantityKg: _roundKg(line.quantityKg),
        ),
  ];
  if (lines.isEmpty) {
    return FeedChange(mill: mill, error: 'Enter the kilos of each ingredient.');
  }
  final saved = FeedFormula(
    id: formula.id,
    name: name,
    lines: lines,
    minimumKg: formula.minimumKg < 0 ? 0 : formula.minimumKg,
  );
  final index = mill.formulas.indexWhere((row) => row.id == formula.id);
  final formulas = [...mill.formulas];
  if (index >= 0) {
    formulas[index] = saved;
  } else {
    formulas.add(saved);
  }
  return FeedChange(
    mill: FeedMill(
      ingredients: _withResources(mill.ingredients, lines),
      formulas: formulas,
      batches: mill.batches,
      issues: mill.issues,
    ),
  );
}

FeedChange mixFeed(
  FeedMill mill, {
  required String id,
  required String number,
  required String formulaId,
  required double quantityKg,
  required DateTime producedOn,
  required String producedBy,
  required DateTime today,
}) {
  FeedFormula? formula;
  for (final row in mill.formulas) {
    if (row.id == formulaId) {
      formula = row;
    }
  }
  if (formula == null) {
    return FeedChange(mill: mill, error: 'Choose the feed to mix.');
  }
  if (quantityKg <= 0) {
    return FeedChange(mill: mill, error: 'Enter how many kilos to mix.');
  }
  final who = producedBy.trim();
  if (who.isEmpty) {
    return FeedChange(mill: mill, error: 'Who mixed it?');
  }
  final ahead = _ahead(producedOn, today);
  if (ahead != null) {
    return FeedChange(mill: mill, error: ahead);
  }
  final recipeKg = formula.totalKg;
  if (recipeKg <= 0) {
    return FeedChange(mill: mill, error: 'This recipe has no ingredients.');
  }
  final scale = quantityKg / recipeKg;
  final used = <BatchLine>[];
  for (final line in formula.lines) {
    final need = _roundKg(line.quantityKg * scale);
    if (need <= 0) {
      continue;
    }
    final ingredient = _ingredient(mill, line.ingredientName);
    if (ingredient == null) {
      return FeedChange(
        mill: mill,
        error: '${line.ingredientName} is not in stock.',
      );
    }
    if (ingredient.stockKg + 0.001 < need) {
      return FeedChange(
        mill: mill,
        error:
            'Not enough ${ingredient.name}. Need ${formatKg(need)}, ${formatKg(ingredient.stockKg)} on hand.',
      );
    }
    used.add(
      BatchLine(
        ingredientName: ingredient.name,
        quantityKg: need,
        unitCost: ingredient.unitCost,
      ),
    );
  }
  if (used.isEmpty) {
    return FeedChange(mill: mill, error: 'This recipe has no ingredients.');
  }
  final ingredients = [
    for (final row in mill.ingredients) _afterUse(row, used),
  ];
  final batch = FeedBatch(
    id: id,
    number: number.trim().isEmpty
        ? 'FD-${mill.batches.length + 1}'
        : number.trim(),
    formulaName: formula.name,
    producedOn: _day(producedOn),
    quantityKg: _roundKg(quantityKg),
    lines: used,
    producedBy: who,
  );
  return FeedChange(
    mill: FeedMill(
      ingredients: ingredients,
      formulas: mill.formulas,
      batches: [...mill.batches, batch],
      issues: mill.issues,
    ),
  );
}

FeedChange giveFeed(FeedMill mill, FeedIssue issue, DateTime today) {
  FeedBatch? batch;
  for (final row in mill.batches) {
    if (row.id == issue.batchId) {
      batch = row;
    }
  }
  if (batch == null) {
    return FeedChange(mill: mill, error: 'Choose the mix.');
  }
  if (issue.quantityKg <= 0) {
    return FeedChange(mill: mill, error: 'Enter the kilos.');
  }
  if (issue.pen.trim().isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the pen.');
  }
  if (issue.group.trim().isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the group.');
  }
  final ahead = _ahead(issue.issuedOn, today);
  if (ahead != null) {
    return FeedChange(mill: mill, error: ahead);
  }
  final left = remainingKg(mill, batch.id);
  if (issue.quantityKg > left + 0.001) {
    return FeedChange(
      mill: mill,
      error: 'Only ${formatKg(left)} of ${batch.number} is left.',
    );
  }
  return FeedChange(
    mill: FeedMill(
      ingredients: mill.ingredients,
      formulas: mill.formulas,
      batches: mill.batches,
      issues: [
        ...mill.issues,
        FeedIssue(
          id: issue.id,
          batchId: issue.batchId,
          issuedOn: _day(issue.issuedOn),
          species: issue.species,
          pen: issue.pen.trim(),
          group: issue.group.trim(),
          quantityKg: _roundKg(issue.quantityKg),
        ),
      ],
    ),
  );
}

/// One ingredient a mix will take, and what the store has now.
class MixNeed {
  const MixNeed({
    required this.name,
    required this.needKg,
    required this.haveKg,
  });

  final String name;
  final double needKg;
  final double haveKg;

  bool get short => haveKg + 0.001 < needKg;
}

/// Ingredient kilos for a production quantity, scaled from the recipe.
class MixPlan {
  const MixPlan({required this.lines, this.error});

  final List<MixNeed> lines;
  final String? error;
}

/// Scales a recipe to [quantityKg]. A 100 kg recipe at 1000 kg uses ten times each line.
MixPlan planMix(FeedMill mill, FeedFormula formula, double quantityKg) {
  if (quantityKg <= 0 || formula.totalKg <= 0) {
    return const MixPlan(lines: []);
  }
  final scale = quantityKg / formula.totalKg;
  final lines = <MixNeed>[];
  String? error;
  for (final line in formula.lines) {
    final need = _roundKg(line.quantityKg * scale);
    if (need <= 0) {
      continue;
    }
    final ingredient = _ingredient(mill, line.ingredientName);
    final have = ingredient?.stockKg ?? 0;
    lines.add(MixNeed(name: line.ingredientName, needKg: need, haveKg: have));
    if (ingredient == null) {
      error ??= '${line.ingredientName} is not in stock.';
    } else if (have + 0.001 < need) {
      error ??=
          'Not enough ${ingredient.name}. Need ${formatKg(need)}, ${formatKg(have)} on hand.';
    }
  }
  return MixPlan(lines: lines, error: error);
}

/// Finished feed still in the store, one row per recipe.
class FinishedStock {
  const FinishedStock({
    required this.name,
    required this.leftKg,
    required this.producedKg,
    required this.value,
    required this.minimumKg,
  });

  final String name;
  final double leftKg;
  final double producedKg;
  final double value;
  final double minimumKg;

  bool get low => minimumKg > 0 && leftKg <= minimumKg;
}

List<FinishedStock> finishedFeed(FeedMill mill) {
  final rows = <FinishedStock>[];
  for (final formula in mill.formulas) {
    var left = 0.0;
    var produced = 0.0;
    var value = 0.0;
    for (final batch in mill.batches) {
      if (!_same(batch.formulaName, formula.name)) {
        continue;
      }
      produced += batch.quantityKg;
      final remain = remainingKg(mill, batch.id);
      left += remain;
      value += remain * batch.costPerKg;
    }
    rows.add(
      FinishedStock(
        name: formula.name,
        leftKg: _roundKg(left),
        producedKg: _roundKg(produced),
        value: value,
        minimumKg: formula.minimumKg,
      ),
    );
  }
  rows.sort((a, b) => a.name.compareTo(b.name));
  return rows;
}

/// Ingredient kilos poured into mixes, largest first.
List<(String, double)> ingredientPoured(
  FeedMill mill, {
  DateTime? from,
  DateTime? to,
}) {
  final totals = <String, double>{};
  for (final batch in mill.batches) {
    if (!_inSpan(batch.producedOn, from, to)) {
      continue;
    }
    for (final line in batch.lines) {
      totals[line.ingredientName] =
          (totals[line.ingredientName] ?? 0) + line.quantityKg;
    }
  }
  final rows = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final row in rows) (row.key, _roundKg(row.value))];
}

/// Gives finished feed out, oldest mix of that recipe first.
FeedChange giveFinishedFeed(
  FeedMill mill, {
  required String id,
  required String formulaName,
  required double quantityKg,
  required DateTime issuedOn,
  required Species species,
  required String pen,
  required String group,
  required DateTime today,
}) {
  final name = formulaName.trim();
  if (name.isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the feed.');
  }
  if (quantityKg <= 0) {
    return FeedChange(mill: mill, error: 'Enter the kilos.');
  }
  if (pen.trim().isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the pen.');
  }
  if (group.trim().isEmpty) {
    return FeedChange(mill: mill, error: 'Choose the group.');
  }
  final ahead = _ahead(issuedOn, today);
  if (ahead != null) {
    return FeedChange(mill: mill, error: ahead);
  }
  final batches = [...mill.batches]
    ..sort((a, b) {
      final byDay = a.producedOn.compareTo(b.producedOn);
      if (byDay != 0) {
        return byDay;
      }
      return a.number.compareTo(b.number);
    });
  var need = quantityKg;
  final added = <FeedIssue>[];
  for (final batch in batches) {
    if (need <= 0.001) {
      break;
    }
    if (!_same(batch.formulaName, name)) {
      continue;
    }
    final left = remainingKg(mill, batch.id);
    if (left <= 0) {
      continue;
    }
    final take = need < left ? need : left;
    added.add(
      FeedIssue(
        id: added.isEmpty ? id : '$id-${added.length}',
        batchId: batch.id,
        issuedOn: _day(issuedOn),
        species: species,
        pen: pen.trim(),
        group: group.trim(),
        quantityKg: _roundKg(take),
      ),
    );
    need = _roundKg(need - take);
  }
  if (added.isEmpty || need > 0.001) {
    final have = _roundKg(quantityKg - (need < 0 ? 0 : need));
    return FeedChange(
      mill: mill,
      error: 'Only ${formatKg(have)} of $name is left.',
    );
  }
  return FeedChange(
    mill: FeedMill(
      ingredients: mill.ingredients,
      formulas: mill.formulas,
      batches: mill.batches,
      issues: [...mill.issues, ...added],
    ),
  );
}

List<FeedIngredient> _withResources(
  List<FeedIngredient> current,
  List<FormulaLine> lines,
) {
  final next = [...current];
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  for (final line in lines) {
    if (_ingredient(FeedMill(ingredients: next), line.ingredientName) != null) {
      continue;
    }
    final slug = line.ingredientName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    var id = 'resource-${slug.isEmpty ? 'item' : slug}';
    if (next.any((row) => row.id == id)) {
      id = '$id-${next.length}';
    }
    next.add(
      FeedIngredient(
        id: id,
        name: line.ingredientName,
        stockKg: 0,
        unitCost: 0,
        supplier: 'Not written',
        purchasedOn: day,
        minimumKg: 0,
      ),
    );
  }
  return next;
}

List<FeedPoint> feedTrend(
  FeedMill mill,
  DateTime today, {
  DateTime? from,
  DateTime? to,
}) {
  if (from != null && to != null) {
    return _pointsIn(mill, from, to);
  }
  final end = DateTime(today.year, today.month);
  final points = <FeedPoint>[];
  for (var offset = 5; offset >= 0; offset--) {
    final month = DateTime(end.year, end.month - offset);
    final next = DateTime(month.year, month.month + 1);
    points.add(_point(mill, month, next, _months[month.month - 1]));
  }
  return points;
}

List<FeedPoint> _pointsIn(FeedMill mill, DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  var end = DateTime(to.year, to.month, to.day);
  if (end.isBefore(start)) {
    end = start;
  }
  final span = end.difference(start).inDays;
  if (span <= 31) {
    return [
      for (
        var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))
      )
        _point(
          mill,
          day,
          day.add(const Duration(days: 1)),
          '${day.day}/${day.month}',
        ),
    ];
  }
  if (span <= 120) {
    final points = <FeedPoint>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final next = cursor.add(const Duration(days: 7));
      final stop = next.isAfter(end.add(const Duration(days: 1)))
          ? end.add(const Duration(days: 1))
          : next;
      points.add(_point(mill, cursor, stop, '${cursor.day}/${cursor.month}'));
      cursor = next;
    }
    return points;
  }
  final points = <FeedPoint>[];
  var month = DateTime(start.year, start.month);
  final last = DateTime(end.year, end.month);
  while (!month.isAfter(last)) {
    final next = DateTime(month.year, month.month + 1);
    points.add(_point(mill, month, next, _months[month.month - 1]));
    month = next;
  }
  return points;
}

FeedPoint _point(FeedMill mill, DateTime from, DateTime until, String label) {
  var produced = 0.0;
  var issued = 0.0;
  var cost = 0.0;
  for (final batch in mill.batches) {
    if (_onOrAfter(batch.producedOn, from) &&
        batch.producedOn.isBefore(until)) {
      produced += batch.quantityKg;
      cost += batch.cost;
    }
  }
  for (final issue in mill.issues) {
    if (_onOrAfter(issue.issuedOn, from) && issue.issuedOn.isBefore(until)) {
      issued += issue.quantityKg;
    }
  }
  return FeedPoint(
    label: label,
    producedKg: _roundKg(produced),
    issuedKg: _roundKg(issued),
    cost: cost,
  );
}

bool _onOrAfter(DateTime day, DateTime from) {
  final date = DateTime(day.year, day.month, day.day);
  final start = DateTime(from.year, from.month, from.day);
  return !date.isBefore(start);
}

/// Kilos given out, one slice per kind of animal.
List<FeedSlice> feedGivenBySpecies(
  FeedMill mill, {
  DateTime? from,
  DateTime? to,
}) {
  final totals = {for (final species in Species.values) species: 0.0};
  for (final issue in mill.issues) {
    if (!_inSpan(issue.issuedOn, from, to)) {
      continue;
    }
    totals[issue.species] = (totals[issue.species] ?? 0) + issue.quantityKg;
  }
  return [
    for (final species in Species.values)
      if ((totals[species] ?? 0) > 0)
        FeedSlice(species.plural, _roundKg(totals[species]!), species: species),
  ];
}

/// Kilos given out, one slice per animal group such as Growers or Layers.
List<FeedSlice> feedGivenByGroup(
  FeedMill mill, {
  DateTime? from,
  DateTime? to,
}) {
  return _slicesBy(mill, (issue) => issue.group, from: from, to: to);
}

/// Kilos given out, one slice per pen.
List<FeedSlice> feedGivenByPen(FeedMill mill, {DateTime? from, DateTime? to}) {
  return _slicesBy(mill, (issue) => issue.pen, from: from, to: to);
}

List<FeedSlice> _slicesBy(
  FeedMill mill,
  String Function(FeedIssue issue) name, {
  DateTime? from,
  DateTime? to,
}) {
  final totals = <String, double>{};
  for (final issue in mill.issues) {
    if (!_inSpan(issue.issuedOn, from, to)) {
      continue;
    }
    final label = name(issue).trim();
    if (label.isEmpty) {
      continue;
    }
    totals[label] = (totals[label] ?? 0) + issue.quantityKg;
  }
  final labels = totals.keys.toList()
    ..sort((a, b) => totals[b]!.compareTo(totals[a]!));
  return [
    for (final label in labels) FeedSlice(label, _roundKg(totals[label]!)),
  ];
}

/// Feed given out, grouped for the enterprise chart.
List<FeedPoint> consumptionByEnterprise(FeedMill mill) {
  final totals = {for (final bucket in FeedBucket.values) bucket: 0.0};
  for (final issue in mill.issues) {
    final batch = _batch(mill, issue.batchId);
    final bucket = bucketFor(
      species: issue.species,
      pen: issue.pen,
      group: issue.group,
      formulaName: batch?.formulaName ?? '',
    );
    totals[bucket] = (totals[bucket] ?? 0) + issue.quantityKg;
  }
  return [
    for (final bucket in FeedBucket.values)
      if (bucket != FeedBucket.other && (totals[bucket] ?? 0) > 0)
        FeedPoint(
          label: bucket.label,
          producedKg: 0,
          issuedKg: _roundKg(totals[bucket] ?? 0),
          cost: 0,
        ),
  ];
}

FeedBucket bucketFor({
  required Species species,
  required String pen,
  required String group,
  required String formulaName,
}) {
  final text = '$pen $group $formulaName'.toLowerCase();
  if (text.contains('layer')) {
    return FeedBucket.layers;
  }
  if (text.contains('broiler')) {
    return FeedBucket.broilers;
  }
  if (text.contains('dairy') || text.contains('milk')) {
    return FeedBucket.dairy;
  }
  if (text.contains('beef')) {
    return FeedBucket.beef;
  }
  return switch (species) {
    Species.pig => FeedBucket.pigs,
    Species.poultry => FeedBucket.broilers,
    Species.cattle => FeedBucket.dairy,
    Species.goat || Species.sheep => FeedBucket.other,
  };
}

FeedReport feedReport({
  required FeedMill mill,
  required List<WeightRecord> weights,
  required List<MilkYield> milk,
  required Map<String, double> salesByLabel,
}) {
  final feed = {for (final bucket in FeedBucket.values) bucket: 0.0};
  final cost = {for (final bucket in FeedBucket.values) bucket: 0.0};
  final penFeed = <String, double>{};
  final penBucket = <String, FeedBucket>{};
  for (final issue in mill.issues) {
    final batch = _batch(mill, issue.batchId);
    final bucket = bucketFor(
      species: issue.species,
      pen: issue.pen,
      group: issue.group,
      formulaName: batch?.formulaName ?? '',
    );
    feed[bucket] = (feed[bucket] ?? 0) + issue.quantityKg;
    final lineCost = issue.quantityKg * (batch?.costPerKg ?? 0);
    cost[bucket] = (cost[bucket] ?? 0) + lineCost;
    penFeed[issue.pen] = (penFeed[issue.pen] ?? 0) + issue.quantityKg;
    penBucket[issue.pen] = bucket;
  }
  final gain = {
    FeedBucket.pigs: _gain(weights, Species.pig, layers: false),
    FeedBucket.broilers: _gain(weights, Species.poultry, layers: false),
    FeedBucket.layers: _gain(weights, Species.poultry, layers: true),
    FeedBucket.beef: _gain(weights, Species.cattle, layers: false),
    FeedBucket.dairy: _gain(weights, Species.cattle, layers: false),
  };
  final litres = milk.fold<double>(0, (sum, row) => sum + row.litres);
  final scores = <FeedScore>[
    _score(FeedBucket.pigs, feed, cost, gain, litres, perLitre: false),
    _score(FeedBucket.broilers, feed, cost, gain, litres, perLitre: false),
    _score(FeedBucket.layers, feed, cost, gain, litres, perLitre: false),
    _score(FeedBucket.dairy, feed, cost, gain, litres, perLitre: true),
  ];
  final pensInBucket = <FeedBucket, int>{};
  for (final bucket in penBucket.values) {
    pensInBucket[bucket] = (pensInBucket[bucket] ?? 0) + 1;
  }
  final pens = <PenScore>[];
  for (final pen in penFeed.keys) {
    final bucket = penBucket[pen] ?? FeedBucket.other;
    final only = pensInBucket[bucket] == 1;
    double? fcr;
    if (only && bucket.usesWeight) {
      final gained = gain[bucket] ?? 0;
      final kilos = penFeed[pen] ?? 0;
      if (gained > 0 && kilos > 0) {
        fcr = kilos / gained;
      }
    }
    pens.add(
      PenScore(
        pen: pen,
        kind: bucket.label,
        feedKg: penFeed[pen] ?? 0,
        fcr: fcr,
      ),
    );
  }
  pens.sort((a, b) => a.pen.compareTo(b.pen));
  final ranked = [
    for (final pen in pens)
      if (pen.fcr != null) pen,
  ]..sort((a, b) => a.fcr!.compareTo(b.fcr!));
  final money = <FeedMoneyLine>[];
  for (final bucket in [
    FeedBucket.pigs,
    FeedBucket.beef,
    FeedBucket.dairy,
    FeedBucket.broilers,
    FeedBucket.layers,
  ]) {
    final spent = cost[bucket] ?? 0;
    final label = _salesName(bucket);
    final sold = salesByLabel[label] ?? salesByLabel[bucket.label] ?? 0;
    if (spent <= 0) {
      continue;
    }
    final existing = money.indexWhere((row) => row.enterprise == label);
    if (existing >= 0) {
      final prior = money[existing];
      money[existing] = FeedMoneyLine(
        enterprise: label,
        feedCost: prior.feedCost + spent,
        sales: sold,
      );
    } else {
      money.add(FeedMoneyLine(enterprise: label, feedCost: spent, sales: sold));
    }
  }
  return FeedReport(
    scores: scores,
    pens: pens,
    money: money,
    best: ranked.isEmpty ? null : ranked.first,
    worst: ranked.length < 2 ? null : ranked.last,
  );
}

/// A small mill with stock, four recipes, mixes, and feed given out.
///
/// Limestone is left under its minimum so the low-stock alert has a row.
FeedMill starterFeedMill(DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  FeedMill mill = FeedMill.empty;
  final bought = day.subtract(const Duration(days: 20));
  final opening = [
    ('ing-maize', 'Maize', 2000.0, 3.2, 200.0),
    ('ing-sbm', 'Soybean Meal', 800.0, 8.5, 100.0),
    ('ing-fish', 'Fish Meal', 200.0, 12.0, 40.0),
    ('ing-bran', 'Wheat Bran', 600.0, 2.4, 80.0),
    ('ing-pkc', 'Palm Kernel Cake', 400.0, 1.8, 50.0),
    ('ing-premix', 'Premix', 80.0, 18.0, 40.0),
    ('ing-salt', 'Salt', 40.0, 1.2, 5.0),
    ('ing-lime', 'Limestone', 5.0, 0.8, 30.0),
  ];
  for (final row in opening) {
    mill = buyIngredient(
      mill,
      FeedIngredient(
        id: row.$1,
        name: row.$2,
        stockKg: row.$3,
        unitCost: row.$4,
        supplier: 'Tema mill',
        purchasedOn: bought,
        minimumKg: row.$5,
      ),
      day,
    ).mill;
  }
  final recipes = [
    (
      'recipe-grower',
      'Pig Grower',
      [
        ('Maize', 60.0),
        ('Soybean Meal', 20.0),
        ('Wheat Bran', 15.0),
        ('Palm Kernel Cake', 3.0),
        ('Premix', 1.5),
        ('Salt', 0.5),
      ],
    ),
    (
      'recipe-dairy',
      'Dairy Feed',
      [
        ('Maize', 50.0),
        ('Wheat Bran', 30.0),
        ('Palm Kernel Cake', 15.0),
        ('Soybean Meal', 4.0),
        ('Salt', 1.0),
      ],
    ),
    (
      'recipe-broiler',
      'Broiler Finisher',
      [
        ('Maize', 55.0),
        ('Soybean Meal', 30.0),
        ('Fish Meal', 8.0),
        ('Wheat Bran', 5.0),
        ('Premix', 1.5),
        ('Salt', 0.5),
      ],
    ),
    (
      'recipe-layer',
      'Layer Feed',
      [
        ('Maize', 50.0),
        ('Soybean Meal', 22.0),
        ('Wheat Bran', 15.0),
        ('Limestone', 8.0),
        ('Palm Kernel Cake', 3.0),
        ('Premix', 1.5),
        ('Salt', 0.5),
      ],
    ),
  ];
  for (final recipe in recipes) {
    mill = saveFormula(
      mill,
      FeedFormula(
        id: recipe.$1,
        name: recipe.$2,
        lines: [
          for (final line in recipe.$3)
            FormulaLine(ingredientName: line.$1, quantityKg: line.$2),
        ],
      ),
    ).mill;
  }
  final earlier = day.subtract(const Duration(days: 40));
  mill = mixFeed(
    mill,
    id: 'batch-grower',
    number: 'FD-1',
    formulaId: 'recipe-grower',
    quantityKg: 100,
    producedOn: earlier,
    producedBy: 'Ama',
    today: day,
  ).mill;
  mill = mixFeed(
    mill,
    id: 'batch-dairy',
    number: 'FD-2',
    formulaId: 'recipe-dairy',
    quantityKg: 42,
    producedOn: day,
    producedBy: 'Ama',
    today: day,
  ).mill;
  mill = mixFeed(
    mill,
    id: 'batch-broiler',
    number: 'FD-3',
    formulaId: 'recipe-broiler',
    quantityKg: 20,
    producedOn: day,
    producedBy: 'Ama',
    today: day,
  ).mill;
  mill = mixFeed(
    mill,
    id: 'batch-layer',
    number: 'FD-4',
    formulaId: 'recipe-layer',
    quantityKg: 20,
    producedOn: day,
    producedBy: 'Ama',
    today: day,
  ).mill;
  mill = giveFeed(
    mill,
    FeedIssue(
      id: 'issue-growers',
      batchId: 'batch-grower',
      issuedOn: day,
      species: Species.pig,
      pen: 'Grower Pen A',
      group: 'Growers',
      quantityKg: 90,
    ),
    day,
  ).mill;
  mill = giveFeed(
    mill,
    FeedIssue(
      id: 'issue-dairy',
      batchId: 'batch-dairy',
      issuedOn: day,
      species: Species.cattle,
      pen: 'Dairy Unit',
      group: 'Dairy',
      quantityKg: 42,
    ),
    day,
  ).mill;
  mill = giveFeed(
    mill,
    FeedIssue(
      id: 'issue-broiler',
      batchId: 'batch-broiler',
      issuedOn: day,
      species: Species.poultry,
      pen: 'Broiler House',
      group: 'Broilers',
      quantityKg: 1.8,
    ),
    day,
  ).mill;
  mill = giveFeed(
    mill,
    FeedIssue(
      id: 'issue-layer',
      batchId: 'batch-layer',
      issuedOn: day,
      species: Species.poultry,
      pen: 'Layer House',
      group: 'Layers',
      quantityKg: 2,
    ),
    day,
  ).mill;
  return mill;
}

String _salesName(FeedBucket bucket) {
  return switch (bucket) {
    FeedBucket.pigs => Enterprise.pig.label,
    FeedBucket.beef => Enterprise.beef.label,
    FeedBucket.dairy => Enterprise.dairy.label,
    FeedBucket.broilers || FeedBucket.layers => Enterprise.poultry.label,
    FeedBucket.other => Enterprise.general.label,
  };
}

FeedScore _score(
  FeedBucket bucket,
  Map<FeedBucket, double> feed,
  Map<FeedBucket, double> cost,
  Map<FeedBucket, double> gain,
  double litres, {
  required bool perLitre,
}) {
  final kilos = feed[bucket] ?? 0;
  final gained = gain[bucket] ?? 0;
  final basis = perLitre ? litres : gained;
  return FeedScore(
    name: bucket.label,
    feedKg: kilos,
    gainKg: gained,
    litres: perLitre ? litres : 0,
    cost: cost[bucket] ?? 0,
    perLitre: perLitre,
    fcr: kilos > 0 && basis > 0 ? kilos / basis : null,
  );
}

double _gain(
  List<WeightRecord> weights,
  Species species, {
  required bool layers,
}) {
  final grouped = <String, List<WeightRecord>>{};
  for (final row in weights) {
    if (row.species != species) {
      continue;
    }
    final layerTag = row.animalTag.toLowerCase().contains('layer');
    if (layerTag != layers) {
      continue;
    }
    grouped.putIfAbsent(row.animalTag, () => []).add(row);
  }
  var gained = 0.0;
  for (final rows in grouped.values) {
    final ordered = [...rows]
      ..sort((a, b) => a.weighedOn.compareTo(b.weighedOn));
    if (ordered.length < 2) {
      continue;
    }
    final change = ordered.last.weightKg - ordered.first.weightKg;
    if (change > 0) {
      gained += change;
    }
  }
  return gained;
}

FeedIngredient _afterUse(FeedIngredient row, List<BatchLine> used) {
  for (final line in used) {
    if (_same(line.ingredientName, row.name)) {
      return row.copyWith(stockKg: _roundKg(row.stockKg - line.quantityKg));
    }
  }
  return row;
}

FeedIngredient? _ingredient(FeedMill mill, String name) {
  for (final row in mill.ingredients) {
    if (_same(row.name, name)) {
      return row;
    }
  }
  return null;
}

double _unitCost(FeedMill mill, String name) {
  return _ingredient(mill, name)?.unitCost ?? 0;
}

FeedBatch? _batch(FeedMill mill, String id) {
  for (final row in mill.batches) {
    if (row.id == id) {
      return row;
    }
  }
  return null;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

double _roundKg(double kg) => (kg * 1000).round() / 1000;

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String? _ahead(DateTime day, DateTime today) {
  if (_day(day).isAfter(_day(today))) {
    return 'That date is still ahead.';
  }
  return null;
}

bool _inSpan(DateTime day, DateTime? from, DateTime? to) {
  if (from == null || to == null) {
    return true;
  }
  final date = _day(day);
  return !date.isBefore(_day(from)) && !date.isAfter(_day(to));
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return '';
}

double _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

DateTime _date(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
  }
  return DateTime(1970);
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) {
    return const [];
  }
  return [
    for (final row in value)
      if (row is Map) Map<String, dynamic>.from(row),
  ];
}
