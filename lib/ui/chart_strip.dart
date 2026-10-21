import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';
import 'package:shai_hills_farm/ui/fit_row.dart';

/// One horizontal row of number cards and small pies.
class ChartStrip extends StatelessWidget {
  const ChartStrip({super.key, required this.cards});

  final List<HerdCard> cards;

  @override
  Widget build(BuildContext context) {
    return FitRow(
      height: 248,
      minChildWidth: 180,
      children: [
        for (final card in cards)
          card.slices.isEmpty ? _NumberCard(card: card) : _PieCard(card: card),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({required this.card});

  final HerdCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              card.detail,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _PieCard extends StatelessWidget {
  const _PieCard({required this.card});

  final HerdCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = [
      for (var index = 0; index < card.slices.length; index++)
        if (card.slices[index].value > 0)
          (
            slice: card.slices[index],
            color: chartColors[index % chartColors.length],
          ),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(card.title, style: theme.textTheme.titleMedium),
            if (shown.isEmpty)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(card.detail, style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              Expanded(
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 28,
                    sectionsSpace: 2,
                    sections: [
                      for (final row in shown)
                        PieChartSectionData(
                          value: row.slice.value,
                          color: row.color,
                          radius: 34,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ChartLegend(
                items: [
                  for (final row in shown)
                    (
                      row.color,
                      '${row.slice.label} ${row.slice.value.round()}',
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
