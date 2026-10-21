import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';

const _sliceColors = [
  farmLeaf,
  farmGold,
  farmBrown,
  farmBarn,
  farmSky,
  Color(0xFF5C6B2F),
];

/// Herd mix, born against purchased, and the monthly replacement bars.
class TraceCharts extends StatefulWidget {
  const TraceCharts({super.key, required this.animals});

  final List<Animal> animals;

  @override
  State<TraceCharts> createState() => _TraceChartsState();
}

class _TraceChartsState extends State<TraceCharts> {
  FarmPeriod _period = FarmPeriod.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final composition = herdComposition(widget.animals);
    final split = originSplit(widget.animals);
    final months = originByMonth(widget.animals, DateTime.now(), _period);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Traceability', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final period in FarmPeriod.values)
              ChoiceChip(
                key: Key('period-${period.name}'),
                label: Text(_periodLabel(period)),
                selected: _period == period,
                onSelected: (_) => setState(() => _period = period),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (composition.isNotEmpty)
          _Donut(
            title: 'Herd',
            slices: [
              for (final slice in composition)
                (slice.label, slice.count.toDouble()),
            ],
          ),
        const SizedBox(height: 12),
        if (split.born + split.purchased > 0)
          _Donut(
            title: 'Origin',
            slices: [
              if (split.born > 0) ('Born on farm', split.born.toDouble()),
              if (split.purchased > 0)
                ('Purchased', split.purchased.toDouble()),
            ],
          ),
        if (months.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Born and purchased', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final month in months) ...[
            Text(month.label),
            const SizedBox(height: 4),
            _Stacked(born: month.born, purchased: month.purchased),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

String _periodLabel(FarmPeriod period) {
  return switch (period) {
    FarmPeriod.today => 'Today',
    FarmPeriod.week => 'Week',
    FarmPeriod.month => 'Month',
    FarmPeriod.quarter => 'Quarter',
    FarmPeriod.year => 'Year',
  };
}

class _Donut extends StatelessWidget {
  const _Donut({required this.title, required this.slices});

  final String title;
  final List<(String, double)> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.$2);
    if (total <= 0) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 42,
                  sectionsSpace: 2,
                  sections: [
                    for (var index = 0; index < slices.length; index++)
                      PieChartSectionData(
                        value: slices[index].$2,
                        color: _sliceColors[index % _sliceColors.length],
                        radius: 26,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
            ChartLegend(
              items: [
                for (var index = 0; index < slices.length; index++)
                  (
                    _sliceColors[index % _sliceColors.length],
                    '${slices[index].$1} ${slices[index].$2.round()}',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stacked extends StatelessWidget {
  const _Stacked({required this.born, required this.purchased});

  final int born;
  final int purchased;

  @override
  Widget build(BuildContext context) {
    final total = born + purchased;
    if (total == 0) {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            if (born > 0)
              Expanded(
                flex: born,
                child: const ColoredBox(color: farmLeaf),
              ),
            if (purchased > 0)
              Expanded(
                flex: purchased,
                child: const ColoredBox(color: farmGold),
              ),
          ],
        ),
      ),
    );
  }
}
