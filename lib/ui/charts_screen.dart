import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';
import 'package:shai_hills_farm/ui/fit_row.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';

/// Charts for the herd, health, sales, and expenses, with period filters.
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({
    super.key,
    required this.herd,
    required this.ledger,
    required this.feed,
    required this.showMoney,
    this.workerView = false,
    this.herds = const {},
  });

  final HerdController herd;
  final LedgerController ledger;
  final FeedController feed;
  final bool showMoney;
  final bool workerView;
  final Set<Species> herds;

  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  ChartPreset _preset = ChartPreset.year;
  bool _custom = false;
  DateTime? _customStart;
  DateTime? _customEnd;
  HerdGroup _group = HerdGroup.species;
  Species? _species;
  final _topics = <ChartTopic>{
    ChartTopic.livestock,
    ChartTopic.health,
    ChartTopic.sales,
    ChartTopic.expenses,
    ChartTopic.feed,
  };

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

  void _selectPreset(ChartPreset preset) {
    setState(() {
      _custom = false;
      _preset = preset;
    });
  }

  FarmPeriod get _period {
    return switch (_preset) {
      ChartPreset.today || ChartPreset.yesterday => FarmPeriod.today,
      ChartPreset.week || ChartPreset.lastWeek => FarmPeriod.week,
      ChartPreset.month || ChartPreset.lastMonth => FarmPeriod.month,
      ChartPreset.quarter || ChartPreset.threeMonths => FarmPeriod.quarter,
      ChartPreset.year => FarmPeriod.year,
    };
  }

  Widget _workerStats(BuildContext context) {
    final access = FarmAccess(FarmRole.worker, herds: widget.herds);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 29));
    final scoped = scopeLedger(
      widget.ledger.ledger,
      access,
      widget.herd.animals,
    );
    final monthUses = [
      for (final row in scoped.feedUses)
        if (!DateUtils.dateOnly(row.happenedOn).isBefore(start) &&
            !DateUtils.dateOnly(row.happenedOn).isAfter(today))
          row,
    ];
    final bySpecies = <Species, double>{};
    final byDay = <DateTime, double>{
      for (var offset = 0; offset < 30; offset++)
        start.add(Duration(days: offset)): 0,
    };
    for (final row in monthUses) {
      final day = DateUtils.dateOnly(row.happenedOn);
      bySpecies[row.species] = (bySpecies[row.species] ?? 0) + row.quantityKg;
      byDay[day] = (byDay[day] ?? 0) + row.quantityKg;
    }
    final total = monthUses.fold<double>(0, (sum, row) => sum + row.quantityKg);
    final points = [
      for (final entry in byDay.entries)
        ChartSlice('${entry.key.day}', entry.value),
    ];
    final sick = [
      for (final row in scoped.health)
        if (row.kind == HealthKind.treatment) row,
    ]..sort((a, b) => b.happenedOn.compareTo(a.happenedOn));
    final byNote = <String, int>{};
    for (final row in sick) {
      final note = row.note.trim().isEmpty ? 'Sickness' : row.note.trim();
      byNote[note] = (byNote[note] ?? 0) + 1;
    }
    final theme = Theme.of(context);
    return ListView(
      key: const Key('worker-charts'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('Feed given', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          total <= 0
              ? 'No feed given in the last 30 days.'
              : '${formatKg(total)} given in the last 30 days.',
          style: theme.textTheme.titleMedium,
        ),
        for (final species in access.speciesChoices)
          if ((bySpecies[species] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${species.plural}: ${formatKg(bySpecies[species]!)}',
              ),
            ),
        const SizedBox(height: 12),
        OneLine(title: 'Feed given, last 30 days', points: points, label: 'kg'),
        const SizedBox(height: 20),
        Text('Sick animals', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        if (sick.isEmpty)
          const Text('No sickness recorded for these animals.')
        else ...[
          for (final entry in byNote.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                entry.value == 1
                    ? '1 ${entry.key}'
                    : '${entry.value} ${entry.key}',
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (var index = 0; index < sick.take(40).length; index++) ...[
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    title: Text(sick[index].animalTag),
                    subtitle: Text(
                      '${sick[index].note.isEmpty ? 'Sickness' : sick[index].note} · ${formatFarmDate(sick[index].happenedOn)}',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _toggleTopic(ChartTopic topic) {
    setState(() {
      if (_topics.contains(topic)) {
        _topics.remove(topic);
      } else {
        _topics.add(topic);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.herd,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: widget.ledger,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: widget.feed,
              builder: (context, _) => _body(context),
            );
          },
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (widget.workerView) {
      return _workerStats(context);
    }
    final today = DateTime.now();
    final animals = widget.herd.animals;
    final ledger = widget.ledger.ledger;
    final window = _window(today);
    final livestock = _topics.contains(ChartTopic.livestock);
    final healthOn = _topics.contains(ChartTopic.health);
    final salesOn = widget.showMoney && _topics.contains(ChartTopic.sales);
    final expensesOn =
        widget.showMoney && _topics.contains(ChartTopic.expenses);
    final feedOn = _topics.contains(ChartTopic.feed);
    final insights = [
      for (final insight in farmInsights(
        animals: animals,
        ledger: ledger,
        today: today,
        period: _period,
        showMoney: widget.showMoney,
        window: window,
        mill: widget.feed.mill,
      ))
        if (_topics.contains(insight.topic)) insight,
    ];
    final herd = herdSlices(animals, _group, species: _species);
    final health = healthSlices(
      animals,
      ledger,
      today,
      _period,
      species: _species,
      window: window,
    );
    final deaths = deathsBySpecies(
      ledger,
      today,
      _period,
      species: _species,
      window: window,
    );
    final buckets = moneyBuckets(ledger, today, _period, window: window);
    final sales = salesByEnterprise(ledger, today, _period, window: window);
    final costs = expensesByItem(ledger, today, _period, window: window);
    final nextSales = forecastNext([for (final row in buckets) row.sales]);
    final nextCosts = forecastNext([for (final row in buckets) row.expenses]);
    final pigs = pigPopulation(animals, today);
    final cattle = cattleHerd(animals);
    final litters = litterSeries(ledger, window);
    final milk = milkSeries(ledger, window);
    final mortality = [
      for (final month in deathStacks(ledger, window))
        if (_species == null ||
            month.parts.any((part) => part.label == _species!.plural))
          StackMonth(
            month.label,
            _species == null
                ? month.parts
                : [
                    for (final part in month.parts)
                      if (part.label == _species!.plural) part,
                  ],
          ),
    ];
    final profit = profitByEnterprise(ledger, window);
    final mixed = feedProduced(widget.feed.mill, window);
    final given = feedIssuedStacks(widget.feed.mill, window);
    final showing = livestock || healthOn || salesOn || expensesOn || feedOn;
    final showPigs = _species == null || _species == Species.pig;
    final showCattle = _species == null || _species == Species.cattle;
    final money = <Widget>[
      if (expensesOn)
        MixDonut(
          title: 'Where the money went',
          slices: costs,
          format: formatCedis,
        ),
      if (salesOn || expensesOn)
        MoneyTrend(
          buckets: buckets,
          showSales: salesOn,
          showExpenses: expensesOn,
        ),
      if ((salesOn || expensesOn) && buckets.length >= 2)
        _ForecastCard(
          sales: salesOn ? nextSales : null,
          expenses: expensesOn ? nextCosts : null,
        ),
      if (salesOn)
        MixDonut(
          title: 'Where the money came from',
          slices: sales,
          format: formatCedis,
        ),
      if (salesOn && profit.isNotEmpty)
        ShareBars(
          title: 'Profit by enterprise',
          slices: profit,
          money: true,
          signed: true,
        ),
    ];
    final farm = <Widget>[
      if (livestock) MixDonut(title: 'Herd', slices: herd),
      if (healthOn) ShareBars(title: 'Deaths', slices: deaths),
      if (feedOn && given.isNotEmpty)
        StackedBars(title: 'Feed given out', months: given),
      if (livestock && showPigs && pigs.isNotEmpty)
        MixDonut(title: 'Pigs', slices: pigs),
      if (healthOn) MixDonut(title: 'Health', slices: health),
      if (livestock && showPigs && litters.isNotEmpty)
        OneLine(
          title: 'Piglets born',
          points: [
            for (final point in litters) ChartSlice(point.label, point.left),
          ],
          label: 'Born',
        ),
      if (livestock && showCattle && cattle.isNotEmpty)
        MixDonut(title: 'Cattle', slices: cattle),
      if (feedOn && mixed.isNotEmpty)
        OneLine(title: 'Feed mixed', points: mixed, label: 'Kilograms'),
      if (livestock && showCattle && milk.isNotEmpty)
        OneLine(title: 'Milk', points: milk, label: 'Litres'),
      if (healthOn && mortality.isNotEmpty)
        StackedBars(title: 'Deaths over time', months: mortality),
    ];
    final topics = [
      ChartTopic.livestock,
      ChartTopic.health,
      if (widget.showMoney) ChartTopic.sales,
      if (widget.showMoney) ChartTopic.expenses,
      ChartTopic.feed,
    ];
    return ListView(
      key: const Key('charts-page'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        RangeMenu(
          preset: _preset,
          custom: _custom,
          customLabel: _customStart == null
              ? 'Custom dates'
              : '${formatFarmDate(window.start)} – ${formatFarmDate(window.end)}',
          onPreset: _selectPreset,
          onCustom: _pickRange,
          keyPrefix: 'chart-period',
        ),
        if (_custom && _customStart != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('chart-change-range'),
              onPressed: _pickRange,
              child: Text(
                '${formatFarmDate(window.start)} – ${formatFarmDate(window.end)}',
                key: const Key('chart-custom-range'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('Show', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in topics)
              FilterChip(
                key: Key('chart-topic-${topic.name}'),
                label: Text(_topicLabel(topic)),
                selected: _topics.contains(topic),
                onSelected: (_) => _toggleTopic(topic),
              ),
          ],
        ),
        if (livestock) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                key: const Key('chart-species-all'),
                label: const Text('All species'),
                selected: _species == null,
                onSelected: (_) => setState(() => _species = null),
              ),
              for (final species in Species.values)
                ChoiceChip(
                  key: Key('chart-species-${species.wire}'),
                  label: Text(species.plural),
                  selected: _species == species,
                  onSelected: (_) => setState(() => _species = species),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final group in HerdGroup.values)
                ChoiceChip(
                  key: Key('chart-group-${group.name}'),
                  label: Text(_groupLabel(group)),
                  selected: _group == group,
                  onSelected: (_) => setState(() => _group = group),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (!showing)
          const Text('Choose livestock, health, sales, expenses, or feed.')
        else ...[
          if (insights.isNotEmpty) ...[
            FitRow(
              height: 132,
              minChildWidth: 180,
              children: [
                for (final insight in insights) _InsightCard(insight: insight),
              ],
            ),
            const SizedBox(height: 16),
          ],
          ..._fitCharts(context, money),
          if (money.isNotEmpty && farm.isNotEmpty) const SizedBox(height: 12),
          ..._fitCharts(context, farm),
        ],
      ],
    );
  }
}

List<Widget> _fitCharts(BuildContext context, List<Widget> items) {
  final wide = MediaQuery.sizeOf(context).width >= 900;
  if (!wide || items.length < 2) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        if (index > 0) const SizedBox(height: 12),
        items[index],
      ],
    ];
  }
  final rows = <Widget>[];
  for (var index = 0; index < items.length; index += 2) {
    if (rows.isNotEmpty) {
      rows.add(const SizedBox(height: 12));
    }
    if (index + 1 >= items.length) {
      rows.add(items[index]);
      continue;
    }
    rows.add(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: items[index]),
          const SizedBox(width: 12),
          Expanded(child: items[index + 1]),
        ],
      ),
    );
  }
  return rows;
}

String _topicLabel(ChartTopic topic) {
  return switch (topic) {
    ChartTopic.livestock => 'Livestock',
    ChartTopic.health => 'Health',
    ChartTopic.sales => 'Sales',
    ChartTopic.expenses => 'Expenses',
    ChartTopic.feed => 'Feed',
  };
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.sales, required this.expenses});

  final double? sales;
  final double? expenses;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (sales != null) '${formatCedis(sales!.roundToDouble())} in sales',
      if (expenses != null)
        '${formatCedis(expenses!.roundToDouble())} in expenses',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forecast', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'If the recent change continues, the next stretch is about ${parts.join(' and ')}.',
              key: const Key('forecast-line'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final FarmInsight insight;

  @override
  Widget build(BuildContext context) {
    final color = switch (insight.tone) {
      InsightTone.healthy => farmLeaf,
      InsightTone.watch => farmGold,
      InsightTone.critical => farmBarn,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: farmPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: farmLine),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ColoredBox(color: color, child: const SizedBox(width: 8)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insight.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        insight.detail,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _groupLabel(HerdGroup group) {
  return switch (group) {
    HerdGroup.species => 'Species',
    HerdGroup.sex => 'Sex',
    HerdGroup.status => 'Status',
  };
}
