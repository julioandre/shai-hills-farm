import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';

const chartColors = [
  farmLeaf,
  farmGold,
  farmBrown,
  farmBarn,
  farmSky,
  Color(0xFF5C6B2F),
];

String chartAmount(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

/// Legend swatches, two on a row when the card is wide enough.
class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key, required this.items});

  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 280 ? 2 : 1;
        final width = columns == 2
            ? (constraints.maxWidth - gap) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: 8,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: item.$1,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.$2,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pig stock as a donut: sows, boars, and growers.
class PigMixChart extends StatelessWidget {
  const PigMixChart({
    super.key,
    required this.sows,
    required this.boars,
    required this.growers,
  });

  final int sows;
  final int boars;
  final int growers;

  @override
  Widget build(BuildContext context) {
    final total = sows + boars + growers;
    if (total == 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final slices = [
      (PigClass.sow, sows, farmLeaf),
      (PigClass.boar, boars, farmBrown),
      (PigClass.grower, growers, farmGold),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Piggery', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '$total pigs at the Piggery Site',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  centerSpaceRadius: 46,
                  sectionsSpace: 2,
                  sections: [
                    for (final slice in slices)
                      if (slice.$2 > 0)
                        PieChartSectionData(
                          value: slice.$2.toDouble(),
                          color: slice.$3,
                          radius: 28,
                          showTitle: false,
                        ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ChartLegend(
              items: [
                for (final slice in slices)
                  (slice.$3, '${slice.$1.label} ${slice.$2}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Revenue this month, one bar per enterprise.
class RevenueBars extends StatelessWidget {
  const RevenueBars({super.key, required this.revenue, this.onSelect});

  final Map<Enterprise, double> revenue;
  final ValueChanged<Enterprise>? onSelect;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final enterprise in Enterprise.values)
        if (enterprise != Enterprise.general && (revenue[enterprise] ?? 0) > 0)
          (enterprise, revenue[enterprise]!),
    ];
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }
    final peak = rows.map((row) => row.$2).reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Revenue this month', style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final row in rows) ...[
              InkWell(
                onTap: onSelect == null ? null : () => onSelect!(row.$1),
                child: Text(row.$1.label, style: theme.textTheme.titleSmall),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 18,
                        value: peak == 0 ? 0 : row.$2 / peak,
                        backgroundColor: farmMist,
                        color: farmLeaf,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(formatCedis(row.$2)),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// A donut for any labelled counts. An empty list shows the title only.
class MixDonut extends StatelessWidget {
  const MixDonut({
    super.key,
    required this.title,
    required this.slices,
    this.subtitle,
    this.colors,
    this.format,
  });

  final String title;
  final String? subtitle;
  final List<ChartSlice> slices;
  final List<Color>? colors;
  final String Function(double value)? format;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = <({ChartSlice slice, Color color})>[];
    for (var index = 0; index < slices.length; index++) {
      if (slices[index].value <= 0) {
        continue;
      }
      final color = colors != null && index < colors!.length
          ? colors![index]
          : chartColors[shown.length % chartColors.length];
      shown.add((slice: slices[index], color: color));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            if (shown.isEmpty)
              const Text('None yet.')
            else ...[
              SizedBox(
                height: 220,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 52,
                    sectionsSpace: 2,
                    sections: [
                      for (final row in shown)
                        PieChartSectionData(
                          value: row.slice.value,
                          color: row.color,
                          radius: 46,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ChartLegend(
                items: [
                  for (final row in shown)
                    (
                      row.color,
                      '${row.slice.label} ${format?.call(row.slice.value) ?? _sliceText(row.slice.value)}',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Horizontal bars. [money] prints cedis; otherwise it prints a count.
class ShareBars extends StatelessWidget {
  const ShareBars({
    super.key,
    required this.title,
    required this.slices,
    this.money = false,
    this.signed = false,
  });

  final String title;
  final List<ChartSlice> slices;
  final bool money;

  /// Keep bars whose value is below zero, and colour those bars red.
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final shown = [
      for (final slice in slices)
        if (signed ? slice.value != 0 : slice.value > 0) slice,
    ];
    if (shown.isEmpty) {
      return const SizedBox.shrink();
    }
    final peak = shown
        .map((slice) => slice.value.abs())
        .reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            for (var i = 0; i < shown.length; i++) ...[
              Text(shown[i].label, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 16,
                        value: peak == 0 ? 0 : shown[i].value.abs() / peak,
                        backgroundColor: farmMist,
                        color: shown[i].value < 0
                            ? farmBarn
                            : chartColors[i % chartColors.length],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    money
                        ? formatCedis(shown[i].value)
                        : _sliceText(shown[i].value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sales and expenses across the selected period.
class MoneyTrend extends StatelessWidget {
  const MoneyTrend({
    super.key,
    required this.buckets,
    this.showSales = true,
    this.showExpenses = true,
  });

  final List<MoneyBucket> buckets;
  final bool showSales;
  final bool showExpenses;

  @override
  Widget build(BuildContext context) {
    final hasSales = showSales && buckets.any((row) => row.sales > 0);
    final hasExpenses = showExpenses && buckets.any((row) => row.expenses > 0);
    final showProfit = hasSales && hasExpenses;
    if (!hasSales && !hasExpenses) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No sales or expenses in this period.'),
        ),
      );
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                showProfit
                    ? 'Sales, expenses, and profit'
                    : hasSales
                    ? 'Sales'
                    : 'Expenses',
                style: theme.textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChartLegend(
                items: [
                  if (hasSales)
                    (
                      farmLeaf,
                      'Sales ${formatCedis(buckets.fold<double>(0, (sum, row) => sum + row.sales))}',
                    ),
                  if (hasExpenses)
                    (
                      farmBarn,
                      'Expenses ${formatCedis(buckets.fold<double>(0, (sum, row) => sum + row.expenses))}',
                    ),
                  if (showProfit)
                    (
                      farmGold,
                      'Profit ${formatCedis(buckets.fold<double>(0, (sum, row) => sum + row.sales - row.expenses))}',
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: buckets.length > 8 ? 2 : 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 ||
                              index >= buckets.length ||
                              (value - index).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          return Text(
                            buckets[index].label,
                            style: theme.textTheme.labelSmall,
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    if (hasSales)
                      _line(farmLeaf, [for (final row in buckets) row.sales]),
                    if (hasExpenses)
                      _line(farmBarn, [
                        for (final row in buckets) row.expenses,
                      ]),
                    if (showProfit)
                      _line(farmGold, [
                        for (final row in buckets) row.sales - row.expenses,
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _line(Color color, List<double> values) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      color: color,
      barWidth: 3,
      isCurved: false,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.12),
      ),
    );
  }
}

/// Two lines that share the same dates.
class TwinLines extends StatelessWidget {
  const TwinLines({
    super.key,
    required this.title,
    required this.points,
    required this.leftLabel,
    required this.rightLabel,
    this.leftColor = farmLeaf,
    this.rightColor = farmGold,
  });

  final String title;
  final List<DualPoint> points;
  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChartLegend(
                items: [
                  (
                    leftColor,
                    '$leftLabel ${chartAmount(points.fold<double>(0, (sum, point) => sum + point.left))}',
                  ),
                  (
                    rightColor,
                    '$rightLabel ${chartAmount(points.fold<double>(0, (sum, point) => sum + point.right))}',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: _bottomTitles(theme.textTheme, [
                    for (final point in points) point.label,
                  ]),
                  lineBarsData: [
                    _series(leftColor, [
                      for (final point in points) point.left,
                    ]),
                    _series(rightColor, [
                      for (final point in points) point.right,
                    ]),
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

/// One line, such as milk or feed mixed.
class OneLine extends StatelessWidget {
  const OneLine({
    super.key,
    required this.title,
    required this.points,
    required this.label,
    this.color = farmLeaf,
  });

  final String title;
  final List<ChartSlice> points;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChartLegend(
                items: [
                  (
                    color,
                    '$label ${chartAmount(points.fold<double>(0, (sum, point) => sum + point.value))}',
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: _bottomTitles(theme.textTheme, [
                    for (final point in points) point.label,
                  ]),
                  lineBarsData: [
                    _series(color, [for (final point in points) point.value]),
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

/// Stacked bars. Each month is one bar made of named parts.
class StackedBars extends StatelessWidget {
  const StackedBars({super.key, required this.title, required this.months});

  final String title;
  final List<StackMonth> months;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }
    final names = <String>[];
    for (final month in months) {
      for (final part in month.parts) {
        if (!names.contains(part.label)) {
          names.add(part.label);
        }
      }
    }
    final colors = {
      for (var i = 0; i < names.length; i++)
        names[i]: chartColors[i % chartColors.length],
    };
    final totals = {for (final name in names) name: 0.0};
    for (final month in months) {
      for (final part in month.parts) {
        totals[part.label] = (totals[part.label] ?? 0) + part.value;
      }
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ChartLegend(
                items: [
                  for (final name in names)
                    (colors[name]!, '$name ${chartAmount(totals[name] ?? 0)}'),
                ],
              ),
            ),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: _bottomTitles(theme.textTheme, [
                    for (final month in months) month.label,
                  ]),
                  barGroups: [
                    for (var i = 0; i < months.length; i++)
                      _stack(i, months[i], colors),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _stack(
    int index,
    StackMonth month,
    Map<String, Color> colors,
  ) {
    var cursor = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final part in month.parts) {
      final next = cursor + part.value;
      items.add(BarChartRodStackItem(cursor, next, colors[part.label]!));
      cursor = next;
    }
    return BarChartGroupData(
      x: index,
      barRods: [
        BarChartRodData(
          toY: cursor,
          rodStackItems: items,
          width: 18,
          borderRadius: BorderRadius.circular(4),
          color: farmMist,
        ),
      ],
    );
  }
}

FlTitlesData _bottomTitles(TextTheme theme, List<String> labels) {
  return FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 28,
        interval: labels.length > 8 ? 2 : 1,
        getTitlesWidget: (value, meta) {
          final index = value.round();
          if (index < 0 ||
              index >= labels.length ||
              (value - index).abs() > 0.01) {
            return const SizedBox.shrink();
          }
          return Text(labels[index], style: theme.labelSmall);
        },
      ),
    ),
  );
}

LineChartBarData _series(Color color, List<double> values) {
  return LineChartBarData(
    spots: [
      for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ],
    color: color,
    barWidth: 3,
    isCurved: false,
    dotData: const FlDotData(show: false),
    belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
  );
}

String _sliceText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}
