import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_scope.dart';
import 'package:shai_hills_farm/domain/feed_stock.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';

enum FarmBoard { farm, pigs, cattle, birds, jobs, feed }

class FarmBoardPicker extends StatefulWidget {
  const FarmBoardPicker({
    super.key,
    required this.farmChild,
    required this.animals,
    required this.ledger,
    required this.showMoney,
  });

  final Widget farmChild;
  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;

  @override
  State<FarmBoardPicker> createState() => _FarmBoardPickerState();
}

class _FarmBoardPickerState extends State<FarmBoardPicker> {
  FarmBoard _board = FarmBoard.farm;

  @override
  Widget build(BuildContext context) {
    const labels = {
      FarmBoard.farm: 'Farm',
      FarmBoard.pigs: 'Piggery',
      FarmBoard.cattle: 'Cattle',
      FarmBoard.birds: 'Birds',
      FarmBoard.jobs: 'Jobs',
      FarmBoard.feed: 'Feed',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final board in FarmBoard.values)
              ChoiceChip(
                key: Key('board-${board.name}'),
                label: Text(labels[board]!),
                selected: _board == board,
                onSelected: (_) => setState(() => _board = board),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_board == FarmBoard.farm)
          widget.farmChild
        else
          BoardPages(
            board: _board,
            animals: widget.animals,
            ledger: widget.ledger,
            showMoney: widget.showMoney,
          ),
      ],
    );
  }
}

/// Piggery, cattle, birds, jobs, and feed stock. The farm view stays on Home.
class BoardPages extends StatelessWidget {
  const BoardPages({
    super.key,
    required this.board,
    required this.animals,
    required this.ledger,
    required this.showMoney,
  });

  final FarmBoard board;
  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    return switch (board) {
      FarmBoard.farm => const SizedBox.shrink(),
      FarmBoard.pigs => _PigsBoard(
        animals: animals,
        ledger: ledger,
        showMoney: showMoney,
        today: today,
      ),
      FarmBoard.cattle => _CattleBoard(
        animals: animals,
        ledger: ledger,
        showMoney: showMoney,
        today: today,
      ),
      FarmBoard.birds => _BirdsBoard(
        animals: animals,
        ledger: ledger,
        showMoney: showMoney,
        today: today,
      ),
      FarmBoard.jobs => _JobsBoard(ledger: ledger, today: today),
      FarmBoard.feed => _FeedBoard(ledger: ledger),
    };
  }
}

class _PigsBoard extends StatelessWidget {
  const _PigsBoard({
    required this.animals,
    required this.ledger,
    required this.showMoney,
    required this.today,
  });

  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final kpis = FarmKpis.evaluate(
      animals: animals,
      ledger: ledger,
      today: today,
    );
    var sows = 0;
    var boars = 0;
    var growers = 0;
    for (final animal in animals) {
      if (animal.species != Species.pig ||
          animal.status != AnimalStatus.onFarm) {
        continue;
      }
      switch (pigClassOf(animal)) {
        case PigClass.sow:
          sows += 1;
        case PigClass.boar:
          boars += 1;
        case PigClass.grower:
          growers += 1;
      }
    }
    final births = [
      for (final row in ledger.births)
        if (row.species == Species.pig && sameMonth(row.happenedOn, today)) row,
    ];
    final born = births.fold<int>(0, (sum, row) => sum + row.bornAlive);
    final deaths = ledger.deaths
        .where(
          (row) =>
              row.species == Species.pig && sameMonth(row.happenedOn, today),
        )
        .length;
    final feedKg = ledger.feedUses
        .where(
          (row) =>
              row.species == Species.pig && sameMonth(row.happenedOn, today),
        )
        .fold<double>(0, (sum, row) => sum + row.quantityKg);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PigMixChart(sows: sows, boars: boars, growers: growers),
        const SizedBox(height: 12),
        _TapLine(
          title: '$born piglets born alive this month',
          detail: births.isEmpty
              ? 'No farrowing written this month.'
              : '${births.length} farrowings · $deaths pig deaths · ${feedKg.round()} kg feed',
          onTap: () => _openLines(context, 'Farrowings this month', [
            for (final row in births)
              '${row.damTag}: ${row.bornAlive} alive, ${row.stillborn} stillborn',
          ]),
        ),
        if (kpis.farrowingRate != null)
          Text(
            'Farrowing rate ${(kpis.farrowingRate! * 100).round()}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (showMoney && kpis.sowScores.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Top sows', style: Theme.of(context).textTheme.titleLarge),
          for (final sow in kpis.sowScores.take(5))
            _TapLine(
              title: sow.damTag,
              detail: '${sow.score.round()} born alive per litter',
              onTap: () => _openLines(context, sow.damTag, [
                '${sow.litters} litters on record',
                '${sow.score.round()} born alive per litter',
              ]),
            ),
        ],
      ],
    );
  }
}

class _CattleBoard extends StatelessWidget {
  const _CattleBoard({
    required this.animals,
    required this.ledger,
    required this.showMoney,
    required this.today,
  });

  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final kpis = FarmKpis.evaluate(
      animals: animals,
      ledger: ledger,
      today: today,
    );
    final breeds = <String, int>{};
    for (final animal in animals) {
      if (animal.species != Species.cattle ||
          animal.status != AnimalStatus.onFarm) {
        continue;
      }
      final breed = animal.breed ?? 'Unrecorded';
      breeds[breed] = (breeds[breed] ?? 0) + 1;
    }
    final milk = ledger.milk
        .where((row) => sameMonth(row.happenedOn, today))
        .fold<double>(0, (sum, row) => sum + row.litres);
    final breedSlices = [
      for (final entry in breeds.entries)
        ChartSlice(entry.key, entry.value.toDouble()),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MixDonut(title: 'Cattle', slices: breedSlices),
        const SizedBox(height: 12),
        for (final entry in breeds.entries)
          _TapLine(
            title: entry.key,
            detail: '${entry.value} on the Cattle/Poultry Site',
            onTap: () => _openLines(context, entry.key, [
              for (final animal in animals)
                if (animal.species == Species.cattle &&
                    animal.status == AnimalStatus.onFarm &&
                    (animal.breed ?? 'Unrecorded') == entry.key)
                  animal.tag,
            ]),
          ),
        const SizedBox(height: 8),
        Text('Milk this month ${milk.round()} L'),
        if (kpis.litresPerCow != null)
          Text('${kpis.litresPerCow!.round()} litres per cow'),
        if (showMoney && kpis.cattleGains.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Weight gain', style: Theme.of(context).textTheme.titleLarge),
          for (final cow in kpis.cattleGains.take(5))
            Text(
              cow.underperforming
                  ? '${cow.animalTag} is gaining slowly.'
                  : '${cow.animalTag} gains ${cow.gainPerDay.toStringAsFixed(1)} kg a day.',
              style: TextStyle(
                color: cow.underperforming ? farmBarn : farmLeaf,
              ),
            ),
        ],
      ],
    );
  }
}

class _BirdsBoard extends StatelessWidget {
  const _BirdsBoard({
    required this.animals,
    required this.ledger,
    required this.showMoney,
    required this.today,
  });

  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final housed = animals
        .where(
          (animal) =>
              animal.species == Species.poultry &&
              animal.status == AnimalStatus.onFarm,
        )
        .length;
    final kpis = FarmKpis.evaluate(
      animals: animals,
      ledger: ledger,
      today: today,
    );
    final deaths = ledger.deaths
        .where(
          (row) =>
              row.species == Species.poultry &&
              sameMonth(row.happenedOn, today),
        )
        .length;
    final fill = (housed / poultryComfortCapacity).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Poultry', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 18,
            value: fill,
            backgroundColor: farmMist,
            color: farmGold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          housed == 0
              ? 'No birds housed. Room for $poultryComfortCapacity, or $poultryFullCapacity if every pen is used.'
              : '$housed birds housed. Room for $poultryComfortCapacity, or $poultryFullCapacity if every pen is used.',
        ),
        const SizedBox(height: 8),
        Text(
          deaths == 0
              ? 'No bird deaths this month.'
              : '$deaths bird deaths this month.',
        ),
        if (kpis.poultryFcr != null)
          Text(
            'Feed conversion ${kpis.poultryFcr!.toStringAsFixed(1)} kg feed per kg gained.',
          ),
        if (showMoney)
          Text(
            'Poultry sales ${formatCedis(kpis.revenueByEnterprise[Enterprise.poultry] ?? 0)}',
          ),
      ],
    );
  }
}

class _JobsBoard extends StatelessWidget {
  const _JobsBoard({required this.ledger, required this.today});

  final FarmLedger ledger;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final kpis = FarmKpis.evaluate(
      animals: const [],
      ledger: ledger,
      today: today,
    );
    final day = DateTime(today.year, today.month, today.day);
    final overdue = <FarmAttention>[];
    final due = <FarmAttention>[];
    for (final event in ledger.health) {
      final next = event.nextDue;
      if (next == null) {
        continue;
      }
      final when = DateTime(next.year, next.month, next.day);
      final item = FarmAttention(
        title: '${event.kind.label} due',
        detail: event.animalTag,
      );
      if (when.isBefore(day)) {
        overdue.add(item);
      }
    }
    due.addAll(kpis.attention);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jobs', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (kpis.feedKgToday <= 0)
          const _ToneLine(
            title: 'Feed not written today',
            detail: 'Open Today and record what was used.',
            tone: _Tone.critical,
          ),
        for (final item in overdue)
          _ToneLine(
            title: item.title,
            detail: item.detail,
            tone: _Tone.critical,
          ),
        for (final item in due)
          _ToneLine(title: item.title, detail: item.detail, tone: _Tone.watch),
        if (overdue.isEmpty && due.isEmpty && kpis.feedKgToday > 0)
          const _ToneLine(
            title: 'Nothing overdue',
            detail: 'Feed is written for today.',
            tone: _Tone.good,
          ),
      ],
    );
  }
}

class _FeedBoard extends StatelessWidget {
  const _FeedBoard({required this.ledger});

  final FarmLedger ledger;

  @override
  Widget build(BuildContext context) {
    final bins = feedBins(ledger);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feed on hand', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (bins.isEmpty)
          const Text('No feed bought or used yet.')
        else ...[
          ShareBars(
            title: 'On hand',
            slices: [
              for (final bin in bins)
                if (bin.onHandKg > 0) ChartSlice(bin.feedType, bin.onHandKg),
            ],
          ),
          const SizedBox(height: 12),
          for (final bin in bins)
            _ToneLine(
              title: bin.feedType,
              detail:
                  '${_kg(bin.onHandKg)} on hand · ${_kg(bin.boughtKg)} bought · ${_kg(bin.usedKg)} used',
              tone: bin.short ? _Tone.critical : _Tone.good,
            ),
        ],
      ],
    );
  }
}

enum _Tone { good, watch, critical }

class _ToneLine extends StatelessWidget {
  const _ToneLine({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      _Tone.good => farmLeaf,
      _Tone.watch => farmGold,
      _Tone.critical => farmBarn,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapLine extends StatelessWidget {
  const _TapLine({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            Text(detail),
          ],
        ),
      ),
    );
  }
}

void _openLines(BuildContext context, String title, List<String> lines) {
  final shown = lines.isEmpty ? ['Nothing recorded yet.'] : lines.take(40);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final line in shown) ...[Text(line), const SizedBox(height: 8)],
          if (lines.length > 40)
            Text('${lines.length - 40} more. Search Animals for a tag.'),
        ],
      );
    },
  );
}

String _kg(double value) {
  if (value == value.roundToDouble()) {
    return '${value.round()} kg';
  }
  return '${value.toStringAsFixed(1)} kg';
}
