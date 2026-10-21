import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/herd_counts.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/feed_mill.dart';
import 'package:shai_hills_farm/domain/kpis.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/domain/farm_task.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/state/book_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/state/task_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/farm_charts.dart';
import 'package:shai_hills_farm/ui/page_box.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';
import 'package:shai_hills_farm/ui/species_style.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.herd,
    required this.book,
    required this.ledger,
    required this.phone,
    required this.userId,
    required this.role,
    required this.tasks,
    required this.auth,
    this.herds = const {},
    this.startupNotice,
  });

  final HerdController herd;
  final BookController book;
  final LedgerController ledger;
  final TaskController tasks;
  final AuthController auth;
  final String phone;
  final String userId;
  final FarmRole role;
  final Set<Species> herds;
  final String? startupNotice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: herd,
      builder: (context, _) {
        return ListenableBuilder(
          listenable: book,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: ledger,
              builder: (context, _) => _buildBody(context),
            );
          },
        );
      },
    );
  }

  Widget _buildBody(BuildContext context) {
    if (herd.loading && herd.animals.isEmpty) {
      return const LoadingView(message: 'Loading the herd…');
    }
    if (herd.error != null && herd.animals.isEmpty) {
      return ErrorView(
        title: 'The herd could not be loaded',
        message: herd.error!,
        onRetry: () => herd.load(),
      );
    }
    final access = FarmAccess(role, herds: herds);
    final animals = [
      for (final animal in herd.animals)
        if (access.allows(animal.species)) animal,
    ];
    final ledgerView = scopeLedger(ledger.ledger, access, herd.animals);
    final counts = HerdCounts.fromAnimals(animals);
    return RefreshIndicator(
      onRefresh: () async {
        await herd.load(refresh: true);
        await book.load(refresh: true);
      },
      child: ListView(
        key: const Key('home-page'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (startupNotice != null) ...[
            NoticeBanner(message: startupNotice!),
            const SizedBox(height: 12),
          ],
          if (herd.refreshError != null) ...[
            NoticeBanner(message: herd.refreshError!, isError: true),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => herd.load(refresh: true),
                child: const Text('Try again'),
              ),
            ),
            const SizedBox(height: 8),
          ],
          _FarmHeader(phone: phone),
          const SizedBox(height: 16),
          if (role != FarmRole.worker) ...[
            _TodayBrief(
              animals: animals,
              ledger: ledgerView,
              showMoney: access.viewFinancials,
            ),
            const SizedBox(height: 16),
          ],
          _AssignedTasks(
            tasks: tasks,
            auth: auth,
            userId: userId,
            canAssign: role == FarmRole.admin,
          ),
          const SizedBox(height: 20),
          Text('On the farm', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _HerdCounts(counts: counts, species: access.speciesChoices),
          const SizedBox(height: 16),
          Text(
            _totalSentence(counts.onFarm),
            key: const Key('count-total'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            animals.isEmpty && herd.animals.isNotEmpty
                ? 'None of your animals are on this list yet.'
                : _footnote(counts, animals.length),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.4),
          ),
          if (animals.any((animal) => animal.id.startsWith('sample-'))) ...[
            const SizedBox(height: 8),
            Text(
              'Sample animals and records are on this phone. Add your own beside them.',
              key: const Key('sample-note'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.4),
            ),
          ],
          if (role != FarmRole.worker) ...[
            const SizedBox(height: 20),
            _HomeCharts(
              animals: animals,
              ledger: ledgerView,
              showMoney: access.viewFinancials,
            ),
          ],
          const SizedBox(height: 8),
          _RecentEvents(
            ledger: ledgerView,
            book: [
              for (final entry in book.entries)
                if (_entryVisible(entry, access, herd.animals)) entry,
            ],
            showMoney: access.viewFinancials,
          ),
        ],
      ),
    );
  }
}

bool _entryVisible(FarmEntry entry, FarmAccess access, List<Animal> animals) {
  if (access.seesEveryHerd) {
    return true;
  }
  final tag = entry.animalTag;
  if (tag == null || tag.isEmpty) {
    return true;
  }
  for (final animal in animals) {
    if (animal.tag == tag) {
      return access.allows(animal.species);
    }
  }
  return true;
}

String _totalSentence(int count) {
  if (count == 1) {
    return '1 animal on the farm';
  }
  return '$count animals on the farm';
}

String _footnote(HerdCounts counts, int recorded) {
  if (recorded == 0) {
    return 'Nothing is on the farm yet. Register the first pig, cow, goat, sheep, or bird.';
  }
  if (counts.onFarm == 0) {
    return 'No animals are marked on farm. Sold, slaughtered, dead, and culled records stay on the register and are left out of these counts.';
  }
  return 'Sold, slaughtered, dead, and culled animals stay on the register and are left out of these counts.';
}

class _TodayBrief extends StatelessWidget {
  const _TodayBrief({
    required this.animals,
    required this.ledger,
    required this.showMoney,
  });

  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final kpis = FarmKpis.evaluate(
      animals: animals,
      ledger: ledger,
      today: today,
    );
    final tone = _tone(kpis, showMoney);
    final quietMoney = kpis.salesToday == 0 && kpis.spentToday == 0;
    final cards = <Widget>[
      if (showMoney) ...[
        _PulseCard(
          label: 'Came in',
          value: quietMoney ? 'None yet' : formatCedis(kpis.salesToday),
        ),
        _PulseCard(
          label: 'Went out',
          value: quietMoney ? 'None yet' : formatCedis(kpis.spentToday),
        ),
        _PulseCard(
          label: 'Left today',
          value: quietMoney ? 'None yet' : formatCedis(kpis.profitToday),
          valueColor: quietMoney
              ? null
              : (kpis.profitToday < 0 ? farmBarn : farmLeaf),
        ),
      ],
      _PulseCard(
        label: 'Feed used',
        value: kpis.feedKgToday <= 0
            ? 'None recorded'
            : formatKg(kpis.feedKgToday),
      ),
      if (showMoney && kpis.bestEnterprise != null)
        _PulseCard(label: 'Best', value: kpis.bestEnterprise!.label),
      if (showMoney && kpis.worstEnterprise != null)
        _PulseCard(label: 'Weakest', value: kpis.worstEnterprise!.label),
    ];
    final notes = <String>[
      if (showMoney)
        'This month ${formatCedis(kpis.revenue)} came in. ${formatCedis(kpis.grossMargin)} is left after feed and other costs.',
      if (kpis.sowScores.isNotEmpty) 'Best sow: ${kpis.sowScores.first.damTag}',
      for (final item in kpis.attention.take(2)) item.title,
      if (ledger.pendingCount > 0)
        '${ledger.pendingCount} records are waiting to send.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Today', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: tone.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tone.color.withValues(alpha: 0.45)),
          ),
          child: Text(
            tone.line,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: tone.color, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: cards),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            notes.join('  ·  '),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _FarmTone {
  const _FarmTone(this.line, this.color);

  final String line;
  final Color color;
}

_FarmTone _tone(FarmKpis kpis, bool showMoney) {
  if (kpis.deathsToday > 0) {
    final count = kpis.deathsToday;
    return _FarmTone(
      count == 1
          ? 'A death was recorded today.'
          : '$count deaths were recorded today.',
      farmBarn,
    );
  }
  if (showMoney && kpis.profitToday < 0) {
    return const _FarmTone('More money went out than came in today.', farmGold);
  }
  if (kpis.attention.isNotEmpty) {
    return const _FarmTone('Something needs a look today.', farmGold);
  }
  return const _FarmTone('The farm is steady today.', farmLeaf);
}

class _PulseCard extends StatelessWidget {
  const _PulseCard({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: farmPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: farmLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor ?? farmInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeCharts extends StatelessWidget {
  const _HomeCharts({
    required this.animals,
    required this.ledger,
    required this.showMoney,
  });

  final List<Animal> animals;
  final FarmLedger ledger;
  final bool showMoney;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final herd = herdSlices(animals, HerdGroup.species);
    final deaths = deathsBySpecies(ledger, today, FarmPeriod.year);
    final buckets = showMoney
        ? moneyBuckets(ledger, today, FarmPeriod.year)
        : const <MoneyBucket>[];
    final costs = showMoney
        ? expensesByItem(ledger, today, FarmPeriod.year)
        : const <ChartSlice>[];
    final hasHerd = herd.any((slice) => slice.value > 0);
    final hasDeaths = deaths.any((slice) => slice.value > 0);
    final hasMoney = buckets.any((row) => row.sales > 0 || row.expenses > 0);
    final hasCosts = costs.any((slice) => slice.value > 0);
    if (!hasHerd && !hasDeaths && !hasMoney && !hasCosts) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final charts = <Widget>[
      if (hasHerd)
        MixDonut(
          title: 'Herd',
          subtitle: 'Animals still on the farm',
          slices: herd,
        ),
      if (hasDeaths) ShareBars(title: 'Deaths this year', slices: deaths),
      if (hasMoney) MoneyTrend(buckets: buckets),
      if (hasCosts)
        ShareBars(title: 'Expenses this year', slices: costs, money: true),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This year', style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'The main picture. Open Charts to pick dates or hide a group.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < charts.length; index++) ...[
          if (index > 0) const SizedBox(height: 12),
          charts[index],
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RecentEvents extends StatefulWidget {
  const _RecentEvents({
    required this.ledger,
    required this.book,
    required this.showMoney,
  });

  final FarmLedger ledger;
  final List<FarmEntry> book;
  final bool showMoney;

  @override
  State<_RecentEvents> createState() => _RecentEventsState();
}

class _RecentEventsState extends State<_RecentEvents> {
  bool _week = true;
  int _page = 0;
  int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final events = recentFarmEvents(
      ledger: widget.ledger,
      book: widget.book,
      today: today,
      thisWeek: _week,
      showMoney: widget.showMoney,
    );
    final shown = events.skip(_page * _pageSize).take(_pageSize).toList();
    final days = <DateTime, List<HomeEvent>>{};
    for (final event in shown) {
      final day = DateTime(event.day.year, event.day.month, event.day.day);
      days.putIfAbsent(day, () => []).add(event);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('home-today'),
              label: const Text('Today'),
              selected: !_week,
              onSelected: (_) => setState(() {
                _week = false;
                _page = 0;
              }),
            ),
            ChoiceChip(
              key: const Key('home-week'),
              label: const Text('This week'),
              selected: _week,
              onSelected: (_) => setState(() {
                _week = true;
                _page = 0;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (shown.isEmpty)
          Text(
            _week
                ? 'Nothing recorded this week yet.'
                : 'Nothing recorded today yet.',
            key: const Key('today-summary'),
            style: theme.textTheme.bodyMedium,
          )
        else
          for (final day in days.keys) ...[
            Text(
              _dayLabel(day, today),
              style: theme.textTheme.titleSmall?.copyWith(color: farmBrown),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final event in days[day]!) _EventRow(event: event),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        PageBar(
          count: events.length,
          page: _page,
          pageSize: _pageSize,
          onPage: (page) => setState(() => _page = page),
          onPageSize: (size) => setState(() {
            _pageSize = size;
            _page = 0;
          }),
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final HomeEvent event;

  @override
  Widget build(BuildContext context) {
    final color = switch (event.title) {
      'Death' || 'Sickness' => farmBarn,
      'Sale' || 'Birth' || 'Milk' => farmLeaf,
      'Expense' || 'Feed' => farmGold,
      _ => farmBrown,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(event.detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _dayLabel(DateTime day, DateTime today) {
  final date = DateTime(day.year, day.month, day.day);
  final end = DateTime(today.year, today.month, today.day);
  if (date == end) {
    return 'Today';
  }
  if (date == end.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  return formatFarmDate(date);
}

class _FarmHeader extends StatelessWidget {
  const _FarmHeader({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          displayPhone(phone),
          key: const Key('welcome-user'),
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
  }
}

class _AssignedTasks extends StatefulWidget {
  const _AssignedTasks({
    required this.tasks,
    required this.auth,
    required this.userId,
    required this.canAssign,
  });

  final TaskController tasks;
  final AuthController auth;
  final String userId;
  final bool canAssign;

  @override
  State<_AssignedTasks> createState() => _AssignedTasksState();
}

class _AssignedTasksState extends State<_AssignedTasks> {
  final _title = TextEditingController();
  List<FarmPerson> _people = [];
  String? _assignee;
  String? _error;
  int _taskPage = 0;
  int _taskPageSize = 10;

  @override
  void initState() {
    super.initState();
    if (widget.canAssign) {
      unawaited(_loadPeople());
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    try {
      final people = await widget.auth.listPeople();
      if (!mounted) {
        return;
      }
      setState(() {
        _people = people;
        _assignee ??= _people.isEmpty ? null : _people.first.userId;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'The people list could not be opened.');
    }
  }

  Future<void> _add() async {
    final error = await widget.tasks.add(
      title: _title.text,
      assigneeId: _assignee ?? '',
    );
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    if (error == null) {
      _title.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.tasks,
      builder: (context, _) {
        final visible = [
          for (final task in widget.tasks.tasks)
            if (widget.canAssign || task.assigneeId == widget.userId) task,
        ];
        final open = [
          for (final task in visible)
            if (!task.done) task,
        ];
        final done = [
          for (final task in visible)
            if (task.done) task,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tasks', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (widget.canAssign) ...[
              TextField(
                key: const Key('task-title'),
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'New task',
                  hintText: 'What should they do?',
                ),
              ),
              const SizedBox(height: 8),
              if (_people.isNotEmpty)
                DropdownButtonFormField<String>(
                  key: const Key('task-person'),
                  initialValue: _assignee,
                  isExpanded: true,
                  decoration: farmDropdownDecoration('Who'),
                  items: [
                    for (final person in _people)
                      DropdownMenuItem(
                        value: person.userId,
                        child: Text(_who(person)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _assignee = value),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const Key('task-add'),
                  onPressed: _add,
                  child: const Text('Add task'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_error != null) ...[
              NoticeBanner(message: _error!, isError: true),
              const SizedBox(height: 8),
            ],
            if (visible.isEmpty)
              const Text('No tasks yet.')
            else ...[
              Card(
                child: Column(
                  children: [
                    for (final task in [
                      ...open,
                      ...done,
                    ].skip(_taskPage * _taskPageSize).take(_taskPageSize))
                      CheckboxListTile(
                        key: Key('task-${task.id}'),
                        value: task.done,
                        title: Text(task.title),
                        subtitle: widget.canAssign
                            ? Text(_personLabel(task))
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) =>
                            widget.tasks.setDone(task.id, value ?? false),
                      ),
                  ],
                ),
              ),
              PageBar(
                count: visible.length,
                page: _taskPage,
                pageSize: _taskPageSize,
                onPage: (page) => setState(() => _taskPage = page),
                onPageSize: (size) => setState(() {
                  _taskPageSize = size;
                  _taskPage = 0;
                }),
              ),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _personLabel(FarmTask task) {
    for (final person in _people) {
      if (person.userId == task.assigneeId) {
        return _who(person);
      }
    }
    return 'Worker';
  }
}

String _who(FarmPerson person) {
  final name = person.name.trim();
  return name.isEmpty ? displayPhone(person.phone) : name;
}

int _countFor(HerdCounts counts, Species species) {
  return switch (species) {
    Species.pig => counts.pigs,
    Species.cattle => counts.cattle,
    Species.goat => counts.goats,
    Species.sheep => counts.sheep,
    Species.poultry => counts.poultry,
  };
}

class _HerdCounts extends StatelessWidget {
  const _HerdCounts({required this.counts, required this.species});

  final HerdCounts counts;
  final List<Species> species;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final kind in species)
        _CountCard(species: kind, count: _countFor(counts, kind)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 640) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < cards.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: cards[index]),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var index = 0; index < cards.length; index += 2) ...[
              if (index > 0) const SizedBox(height: 12),
              if (index + 1 < cards.length)
                _CountRow(left: cards[index], right: cards[index + 1])
              else
                cards[index],
            ],
          ],
        );
      },
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.species, required this.count});

  final Species species;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${species.plural}, $count on the farm',
      child: DecoratedBox(
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
                ColoredBox(
                  color: speciesColor(species),
                  child: const SizedBox(width: 6),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            species.plural,
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '$count',
                            key: Key('count-${species.wire}'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
