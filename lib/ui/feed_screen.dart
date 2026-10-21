import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/card_grid.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';
import 'package:shai_hills_farm/ui/page_box.dart';
import 'package:shai_hills_farm/ui/feed_form_screen.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';
import 'package:shai_hills_farm/ui/species_style.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

/// Bought feed, mixtures still in the store, and what was given to livestock.
class FeedScreen extends StatefulWidget {
  const FeedScreen({
    super.key,
    required this.feed,
    required this.ledger,
    required this.showMoney,
    required this.canManage,
    this.speciesChoices = const [],
    this.limitedCharts = false,
  });

  final FeedController feed;
  final LedgerController ledger;
  final bool showMoney;
  final bool canManage;
  final List<Species> speciesChoices;
  final bool limitedCharts;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  ChartPreset _preset = ChartPreset.year;
  bool _custom = false;
  DateTime? _customStart;
  DateTime? _customEnd;

  ChartWindow _window(DateTime today) {
    if (_custom && _customStart != null && _customEnd != null) {
      return windowFor(
        FarmPeriod.year,
        today,
        customStart: _customStart,
        customEnd: _customEnd,
      );
    }
    return presetWindow(_preset, today);
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 5),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: _customStart ?? today.subtract(const Duration(days: 29)),
        end: _customEnd ?? today,
      ),
      helpText: 'Choose dates',
      saveText: 'Use these dates',
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _custom = true;
      _customStart = picked.start;
      _customEnd = picked.end;
    });
  }

  Future<void> _open(FeedTask task, {FeedFormula? formula}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => FeedFormScreen(
          feed: widget.feed,
          task: task,
          showMoney: widget.showMoney,
          formula: formula,
          uses: widget.ledger.ledger.feedUses,
          speciesChoices: widget.speciesChoices,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.feed,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: widget.ledger,
          builder: (context, _) => _body(context),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final feed = widget.feed;
    if (feed.loading && feed.mill.ingredients.isEmpty) {
      return const LoadingView(message: 'Loading the feed store…');
    }
    if (feed.error != null && feed.mill.ingredients.isEmpty) {
      return ErrorView(
        title: 'The feed store could not be opened',
        message: feed.error!,
        onRetry: () => feed.load(),
      );
    }
    final mill = feed.mill;
    final today = DateTime.now();
    final stock = stockAfterUse(mill, widget.ledger.ledger.feedUses);
    final lows = [
      for (final row in stock.ingredients)
        if (row.low) row,
    ];
    final sales = {
      for (final slice in salesByEnterprise(
        widget.ledger.ledger,
        today,
        FarmPeriod.year,
      ))
        slice.label: slice.value,
    };
    final report = feedReport(
      mill: mill,
      weights: widget.ledger.ledger.weights,
      milk: widget.ledger.ledger.milk,
      salesByLabel: sales,
    );
    final theme = Theme.of(context);
    final ready = stock.mixtures;
    final finishedLows = [
      for (final row in finishedFeed(mill))
        if (row.low) row,
    ];
    final leftKg = stock.ingredients.fold<double>(
      0,
      (sum, row) => sum + row.leftKg,
    );
    final mixtureKg = ready.fold<double>(0, (sum, row) => sum + row.leftKg);
    return ListView(
      key: const Key('feed-page'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          widget.canManage
              ? 'Buy feed on Money, mix it, then give it out.'
              : 'Mix feed, then give it out.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        _StoreTotals(leftKg: leftKg, mixtureKg: mixtureKg),
        if (stock.shortKg > 0) ...[
          const SizedBox(height: 12),
          Text(
            'Feed use recorded is ${formatKg(stock.shortKg)} more than the feed in the store.',
            key: const Key('feed-short'),
            style: theme.textTheme.titleMedium?.copyWith(color: farmBarn),
          ),
        ],
        if (lows.isNotEmpty || finishedLows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Alert(
            ingredients: lows,
            finished: finishedLows,
            canBuy: widget.canManage,
          ),
        ],
        const SizedBox(height: 20),
        CardGrid(
          minWidth: 280,
          children: [
            _SectionCard(
              title: '1. Feed bought',
              detail: 'Mixing uses these kilos.',
              child: _StockSection(
                rows: stock.ingredients,
                showMoney: widget.showMoney,
              ),
            ),
            _SectionCard(
              title: '2. Mixtures ready',
              detail: 'Finished feed still in the store.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MixtureSection(
                    mill: mill,
                    ready: ready,
                    showMoney: widget.showMoney,
                    onMix: () => _open(FeedTask.mix),
                  ),
                  const SizedBox(height: 12),
                  _RecipeSection(
                    mill: mill,
                    showMoney: widget.showMoney,
                    canManage: widget.canManage,
                    onNew: () => _open(FeedTask.recipe),
                    onOpen: (formula) =>
                        _open(FeedTask.recipe, formula: formula),
                  ),
                ],
              ),
            ),
            _SectionCard(
              title: '3. Given to livestock',
              detail: 'Giving feed out takes it off the mixture stock.',
              child: _IssueSection(
                mill: mill,
                canGive: ready.isNotEmpty,
                speciesChoices: widget.speciesChoices,
                onGive: () => _open(FeedTask.give),
              ),
            ),
          ],
        ),
        if (!widget.limitedCharts) ...[
          const SizedBox(height: 20),
          RangeMenu(
            preset: _preset,
            custom: _custom,
            customLabel: _customStart == null
                ? 'Custom dates'
                : '${formatFarmDate(_window(today).start)} – ${formatFarmDate(_window(today).end)}',
            onPreset: (preset) => setState(() {
              _custom = false;
              _preset = preset;
            }),
            onCustom: _pickRange,
            keyPrefix: 'feed-period',
          ),
          const SizedBox(height: 8),
          Text(
            'Stock above is what is here now. The charts follow these dates.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (!widget.limitedCharts && mill.issues.isNotEmpty) ...[
          const SizedBox(height: 20),
          _GivenCharts(
            mill: mill,
            from: _window(today).start,
            to: _window(today).end,
          ),
        ],
        if (widget.limitedCharts) const SizedBox(height: 8),
        if (!widget.limitedCharts) ...[
          const SizedBox(height: 20),
          Text('Results', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Feed given, weight gained, and milk.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _FeedStrip(report: report, showMoney: widget.showMoney),
          const SizedBox(height: 20),
          _ChartSection(
            mill: mill,
            stock: stock,
            today: today,
            showMoney: widget.showMoney,
            from: _window(today).start,
            to: _window(today).end,
          ),
        ],
      ],
    );
  }
}

class _StoreTotals extends StatelessWidget {
  const _StoreTotals({required this.leftKg, required this.mixtureKg});

  final double leftKg;
  final double mixtureKg;

  @override
  Widget build(BuildContext context) {
    final total = leftKg + mixtureKg;
    final leftShare = total <= 0 ? 0.0 : leftKg / total;
    final mixShare = total <= 0 ? 0.0 : mixtureKg / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 16,
            child: total <= 0
                ? const ColoredBox(color: farmMist)
                : Row(
                    children: [
                      if (leftShare > 0)
                        Expanded(
                          flex: (leftShare * 1000).round().clamp(1, 1000),
                          child: const ColoredBox(color: farmLeaf),
                        ),
                      if (mixShare > 0)
                        Expanded(
                          flex: (mixShare * 1000).round().clamp(1, 1000),
                          child: const ColoredBox(color: farmGold),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        CardGrid(
          minWidth: 180,
          children: [
            _CountCard(
              label: 'Feed left',
              value: formatKg(leftKg),
              color: farmLeaf,
            ),
            _CountCard(
              label: 'Mixture ready',
              value: formatKg(mixtureKg),
              color: farmGold,
            ),
          ],
        ),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.detail,
    required this.child,
  });

  final String title;
  final String detail;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(detail),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.ingredients,
    required this.finished,
    required this.canBuy,
  });

  final List<IngredientOnHand> ingredients;
  final List<FinishedStock> finished;
  final bool canBuy;

  @override
  Widget build(BuildContext context) {
    final next = canBuy
        ? 'Record the purchase on Money before it runs out.'
        : 'Ask a manager to record it on Money before it runs out.';
    final names = [
      for (final row in ingredients) row.ingredient.name,
      for (final row in finished) row.name,
    ];
    final message = names.length == 1
        ? '${names.single} is low. $next'
        : '${names.length} feeds are low: ${names.join(', ')}. $next';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: farmPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: farmLine),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ColoredBox(color: farmBarn, child: SizedBox(width: 8)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    message,
                    key: const Key('feed-low-stock'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedStrip extends StatelessWidget {
  const _FeedStrip({required this.report, required this.showMoney});

  final FeedReport report;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final scores = [
      for (final score in report.scores)
        if (score.feedKg > 0) score,
    ];
    final cards = <Widget>[
      if (scores.isEmpty)
        const _StripNote(
          title: 'No result yet',
          lines: [
            'Give feed out, then weigh the animals twice or record milk.',
          ],
        )
      else
        for (final score in scores)
          _ScoreCard(score: score, showMoney: showMoney),
      if (report.best != null)
        _RankCard(title: 'Best group', pen: report.best!),
      if (report.worst != null && report.worst!.pen != report.best?.pen)
        _RankCard(title: 'Needs attention', pen: report.worst!),
      if (showMoney)
        for (final line in report.money) _MoneyLineCard(line: line),
    ];
    return CardGrid(minWidth: 200, children: cards);
  }
}

class _StripNote extends StatelessWidget {
  const _StripNote({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final line in lines) Text(line),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score, required this.showMoney});

  final FeedScore score;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = score.perLitre
        ? (score.litres > 0
              ? '${formatLitres(score.litres)} of milk'
              : 'No milk recorded')
        : (score.gainKg > 0
              ? '${formatKg(score.gainKg)} gained'
              : 'No second weight yet');
    final line = score.fcr == null
        ? '${formatKg(score.feedKg)} given. $result.'
        : score.perLitre
        ? '${_one(score.fcr!)} kg of feed for each litre'
        : '${_one(score.fcr!)} kg of feed for each kg gained';
    final cost = score.costPerResult;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(score.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('${formatKg(score.feedKg)} given'),
            Text(result),
            Text(line),
            if (showMoney && cost != null)
              Text(
                score.perLitre
                    ? '${formatCedis(cost)} of feed for each litre'
                    : '${formatCedis(cost)} of feed for each kg gained',
              ),
          ],
        ),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  const _RankCard({required this.title, required this.pen});

  final String title;
  final PenScore pen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          '${pen.pen}. ${_one(pen.fcr!)} kg of feed for each kg gained.',
        ),
      ),
    );
  }
}

class _MoneyLineCard extends StatelessWidget {
  const _MoneyLineCard({required this.line});

  final FeedMoneyLine line;

  @override
  Widget build(BuildContext context) {
    final left = line.sales - line.feedCost;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.enterprise,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text('Feed ${formatCedis(line.feedCost)}'),
            Text('Sales ${formatCedis(line.sales)}'),
            Text(
              left >= 0
                  ? '${formatCedis(left)} left after feed'
                  : '${formatCedis(left.abs())} more feed cost than sales',
            ),
          ],
        ),
      ),
    );
  }
}

class _StockSection extends StatelessWidget {
  const _StockSection({required this.rows, required this.showMoney});

  final List<IngredientOnHand> rows;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Text('No ingredients yet. Record a feed expense on Money.');
    }
    return CardGrid(
      minWidth: 180,
      children: [
        for (final row in rows) _BoughtCard(row: row, showMoney: showMoney),
      ],
    );
  }
}

class _BoughtCard extends StatelessWidget {
  const _BoughtCard({required this.row, required this.showMoney});

  final IngredientOnHand row;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bought = row.ingredient.stockKg;
    final left = row.leftKg;
    final share = bought <= 0 ? 0.0 : (left / bought).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: farmPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: farmLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.ingredient.name, style: theme.textTheme.titleMedium),
            Text(
              ingredientGroup(
                name: row.ingredient.name,
                saved: row.ingredient.group,
              ),
            ),
            const SizedBox(height: 8),
            Text('Bought ${formatKg(bought)}'),
            Text('Left ${formatKg(left)}'),
            if (showMoney)
              Text('${formatCedis(row.ingredient.unitCost)} per kg'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 10,
                backgroundColor: farmMist,
                color: row.low ? farmBarn : farmLeaf,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeSection extends StatelessWidget {
  const _RecipeSection({
    required this.mill,
    required this.showMoney,
    required this.canManage,
    required this.onNew,
    required this.onOpen,
  });

  final FeedMill mill;
  final bool showMoney;
  final bool canManage;
  final VoidCallback onNew;
  final ValueChanged<FeedFormula> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recipes', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (canManage)
          FilledButton.icon(
            key: const Key('feed-recipe'),
            onPressed: onNew,
            icon: const Icon(Icons.add),
            label: const Text('New recipe'),
          ),
        const SizedBox(height: 12),
        if (mill.formulas.isEmpty)
          const Text(
            'No recipes yet. Save Pig Grower, Layer Feed, or Dairy Feed.',
          )
        else
          PageBox(
            count: mill.formulas.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(mill.formulas[index].name),
                subtitle: Text(
                  _recipeLine(mill.formulas[index], mill, showMoney),
                ),
                onTap: canManage ? () => onOpen(mill.formulas[index]) : null,
              );
            },
          ),
      ],
    );
  }
}

String _recipeLine(FeedFormula formula, FeedMill mill, bool showMoney) {
  final price = priceFormula(formula, mill);
  if (!showMoney) {
    return formatKg(price.totalKg);
  }
  return '${formatKg(price.totalKg)} · ${formatCedis(price.costPerKg)} per kg';
}

class _MixtureSection extends StatelessWidget {
  const _MixtureSection({
    required this.mill,
    required this.ready,
    required this.showMoney,
    required this.onMix,
  });

  final FeedMill mill;
  final List<MixtureStock> ready;
  final bool showMoney;
  final VoidCallback onMix;

  @override
  Widget build(BuildContext context) {
    final usedUp = mill.batches.length - ready.length;
    final finished = finishedFeed(mill);
    final peak = finished.fold<double>(
      0,
      (max, row) => row.leftKg > max ? row.leftKg : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          key: const Key('feed-mix'),
          onPressed: onMix,
          icon: const Icon(Icons.add),
          label: const Text('Mix feed'),
        ),
        if (finished.isNotEmpty) ...[
          const SizedBox(height: 12),
          CardGrid(
            minWidth: 160,
            children: [
              for (final row in finished)
                _FinishedCard(row: row, peak: peak, showMoney: showMoney),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (ready.isEmpty)
          Text(
            mill.batches.isEmpty
                ? 'No mixture is ready. Mix a batch from the feed in the store.'
                : 'Recorded feed use has used up the mixture in the store.',
          )
        else
          PageBox(
            count: ready.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(ready[index].batch.formulaName),
                subtitle: Text(
                  [
                    ready[index].batch.number,
                    '${formatKg(ready[index].leftKg)} left',
                    if (showMoney)
                      '${formatCedis(ready[index].batch.costPerKg)} per kg',
                  ].join(' · '),
                ),
              );
            },
          ),
        if (usedUp > 0) ...[
          const SizedBox(height: 8),
          Text(
            usedUp == 1
                ? '1 mixture has been used up.'
                : '$usedUp mixtures have been used up.',
          ),
        ],
      ],
    );
  }
}

class _FinishedCard extends StatelessWidget {
  const _FinishedCard({
    required this.row,
    required this.peak,
    required this.showMoney,
  });

  final FinishedStock row;
  final double peak;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final share = peak <= 0 ? 0.0 : (row.leftKg / peak).clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: farmPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: row.low ? farmBarn : farmLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Left ${formatKg(row.leftKg)}'),
            if (showMoney && row.value > 0) Text(formatCedis(row.value)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share,
                minHeight: 10,
                backgroundColor: farmMist,
                color: row.low ? farmBarn : farmGold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueSection extends StatelessWidget {
  const _IssueSection({
    required this.mill,
    required this.canGive,
    required this.onGive,
    this.speciesChoices = const [],
  });

  final FeedMill mill;
  final bool canGive;
  final VoidCallback onGive;
  final List<Species> speciesChoices;

  @override
  Widget build(BuildContext context) {
    final issues = [
      for (final issue in mill.issues.reversed)
        if (speciesChoices.isEmpty || speciesChoices.contains(issue.species))
          issue,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          key: const Key('feed-give'),
          onPressed: canGive ? onGive : null,
          icon: const Icon(Icons.add),
          label: const Text('Give to livestock'),
        ),
        const SizedBox(height: 12),
        if (issues.isEmpty)
          const Text('No feed has been given out yet.')
        else
          PageBox(
            count: issues.length,
            height: 320,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text('${issues[index].pen} · ${issues[index].group}'),
                subtitle: Text(
                  '${formatFarmDate(issues[index].issuedOn)} · ${issues[index].species.plural} · ${formatKg(issues[index].quantityKg)}',
                ),
              );
            },
          ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.mill,
    required this.stock,
    required this.today,
    required this.showMoney,
    required this.from,
    required this.to,
  });

  final FeedMill mill;
  final StoreStock stock;
  final DateTime today;
  final bool showMoney;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    if (mill.batches.isEmpty && mill.ingredients.isEmpty) {
      return const Text('Buy ingredients and mix a batch to see the charts.');
    }
    final trend = feedTrend(mill, today, from: from, to: to);
    final bars = [
      for (final row in stock.ingredients)
        if (row.leftKg > 0) ChartSlice(row.ingredient.name, row.leftKg),
    ];
    final finished = [
      for (final row in finishedFeed(mill))
        if (row.leftKg > 0) ChartSlice(row.name, row.leftKg),
    ];
    final poured = [
      for (final row in ingredientPoured(mill, from: from, to: to))
        if (row.$2 > 0) ChartSlice(row.$1, row.$2),
    ];
    final value = [
      for (final row in finishedFeed(mill))
        if (row.value > 0) ChartSlice(row.name, row.value),
    ];
    final costPerKg = [
      for (final row in trend)
        (row.label, row.producedKg <= 0 ? 0.0 : row.cost / row.producedKg),
    ];
    return Column(
      children: [
        ShareBars(title: 'Ingredient stock', slices: bars),
        const SizedBox(height: 12),
        ShareBars(title: 'Finished feed', slices: finished),
        const SizedBox(height: 12),
        TrendLine(
          title: 'Feed mixed',
          points: [for (final row in trend) (row.label, row.producedKg)],
        ),
        const SizedBox(height: 12),
        TrendLine(
          title: 'Feed given out',
          points: [for (final row in trend) (row.label, row.issuedKg)],
          color: farmGold,
        ),
        const SizedBox(height: 12),
        ShareTreemap(title: 'Ingredients used', slices: poured),
        if (showMoney) ...[
          const SizedBox(height: 12),
          MixDonut(
            title: 'Feed value',
            subtitle: 'Cedis still in finished feed',
            slices: value,
            format: formatCedis,
          ),
          const SizedBox(height: 12),
          TrendLine(title: 'Cost per kg', points: costPerKg, color: farmBrown),
        ],
      ],
    );
  }
}

class _GivenCharts extends StatelessWidget {
  const _GivenCharts({
    required this.mill,
    required this.from,
    required this.to,
  });

  final FeedMill mill;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) {
    final animals = feedGivenBySpecies(mill, from: from, to: to);
    final groups = feedGivenByGroup(mill, from: from, to: to);
    final pens = feedGivenByPen(mill, from: from, to: to);
    final charts = <Widget>[
      if (animals.isNotEmpty)
        MixDonut(
          title: 'Feed given to animals',
          subtitle: 'Kilos given out',
          slices: [for (final row in animals) ChartSlice(row.label, row.kg)],
          colors: [
            for (final row in animals)
              if (row.species != null) speciesColor(row.species!),
          ],
          format: formatKg,
        ),
      if (groups.isNotEmpty)
        MixDonut(
          title: 'Feed given to groups',
          subtitle: 'Growers, sows, broilers, layers, and the rest',
          slices: [for (final row in groups) ChartSlice(row.label, row.kg)],
          format: formatKg,
        ),
      if (pens.isNotEmpty)
        MixDonut(
          title: 'Feed given to pens',
          slices: [for (final row in pens) ChartSlice(row.label, row.kg)],
          format: formatKg,
        ),
    ];
    if (charts.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840 && charts.length >= 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who got the feed',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: charts[0]),
                  const SizedBox(width: 12),
                  Expanded(child: charts[1]),
                ],
              )
            else
              charts[0],
            for (var index = wide ? 2 : 1; index < charts.length; index++) ...[
              const SizedBox(height: 12),
              charts[index],
            ],
          ],
        );
      },
    );
  }
}

String _one(double value) {
  final tenths = (value * 10).round();
  final whole = tenths ~/ 10;
  final fraction = tenths.abs() % 10;
  if (fraction == 0) {
    return '$whole';
  }
  return '$whole.$fraction';
}
