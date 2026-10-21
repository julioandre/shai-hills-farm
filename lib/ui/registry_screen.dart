import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/domain/farm_visuals.dart';
import 'package:shai_hills_farm/domain/ledger.dart';
import 'package:shai_hills_farm/domain/traceability.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/animal_form_screen.dart';
import 'package:shai_hills_farm/ui/chart_strip.dart';
import 'package:shai_hills_farm/ui/page_box.dart';
import 'package:shai_hills_farm/ui/range_menu.dart';
import 'package:shai_hills_farm/ui/species_style.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class RegistryScreen extends StatefulWidget {
  const RegistryScreen({
    super.key,
    required this.herd,
    this.ledger = FarmLedger.empty,
    this.speciesChoices = const [],
  });

  final HerdController herd;
  final FarmLedger ledger;

  /// Empty means every species.
  final List<Species> speciesChoices;

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen> {
  String _query = '';
  Species? _species;
  ChartPreset _preset = ChartPreset.year;
  bool _custom = false;
  DateTime? _customStart;
  DateTime? _customEnd;
  int _page = 0;
  int _pageSize = 10;

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

  void _openForm([Animal? animal]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AnimalFormScreen(
          herd: widget.herd,
          animal: animal,
          ledger: widget.ledger,
          speciesChoices: widget.speciesChoices,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.herd,
      builder: (context, _) {
        final herd = widget.herd;
        if (herd.loading && herd.animals.isEmpty) {
          return const LoadingView(message: 'Loading the herd…');
        }
        if (herd.error != null && herd.animals.isEmpty) {
          return ErrorView(
            title: 'The register could not be loaded',
            message: herd.error!,
            onRetry: () => herd.load(),
          );
        }
        final today = DateTime.now();
        final window = _window(today);
        final choices = widget.speciesChoices.isEmpty
            ? Species.values
            : widget.speciesChoices;
        final animals = [
          for (final animal in herd.animals)
            if (choices.contains(animal.species)) animal,
        ];
        final visible = [
          for (final animal in animals)
            if (_matches(animal)) animal,
        ];
        final cards = herdCards(
          animals: animals,
          ledger: widget.ledger,
          window: window,
          species: _species,
        );
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => herd.load(refresh: true),
                child: ListView(
                  key: const Key('registry-page'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    if (herd.refreshError != null) ...[
                      NoticeBanner(message: herd.refreshError!, isError: true),
                      const SizedBox(height: 12),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final period = RangeMenu(
                          preset: _preset,
                          custom: _custom,
                          customLabel: _customStart == null
                              ? 'Custom dates'
                              : '${formatFarmDate(window.start)} – ${formatFarmDate(window.end)}',
                          onPreset: (preset) => setState(() {
                            _custom = false;
                            _preset = preset;
                          }),
                          onCustom: _pickRange,
                          keyPrefix: 'animal-period',
                        );
                        final search = TextField(
                          key: const Key('search-tag'),
                          decoration: const InputDecoration(
                            hintText: 'Search tag or ID',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() {
                            _query = value;
                            _page = 0;
                          }),
                        );
                        if (constraints.maxWidth < 560) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: search),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: period),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: search),
                            const SizedBox(width: 12),
                            SizedBox(width: 280, child: period),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          key: const Key('filter-all'),
                          label: const Text('All'),
                          selected: _species == null,
                          onSelected: (_) => setState(() {
                            _species = null;
                            _page = 0;
                          }),
                        ),
                        for (final species in choices)
                          FilterChip(
                            key: Key('filter-${species.wire}'),
                            label: Text(species.plural),
                            selected: _species == species,
                            onSelected: (_) => setState(() {
                              _species = species;
                              _page = 0;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ChartStrip(cards: cards),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      _EmptyRegister(
                        filtered: animals.isNotEmpty,
                        onAdd: () => _openForm(),
                      )
                    else ...[
                      Card(
                        child: Column(
                          children: [
                            for (
                              var index = _page * _pageSize;
                              index < visible.length &&
                                  index < (_page + 1) * _pageSize;
                              index++
                            ) ...[
                              if (index > _page * _pageSize)
                                const Divider(height: 1),
                              _AnimalTile(
                                animal: visible[index],
                                onTap: () => _openForm(visible[index]),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PageBar(
                        count: visible.length,
                        page: _page,
                        pageSize: _pageSize,
                        onPage: (page) => setState(() => _page = page),
                        onPageSize: (size) => setState(() {
                          _pageSize = size;
                          _page = 0;
                        }),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _matches(Animal animal) {
    if (_species != null && animal.species != _species) {
      return false;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return animal.tag.toLowerCase().contains(query);
  }
}

class _AnimalTile extends StatelessWidget {
  const _AnimalTile({required this.animal, required this.onTap});

  final Animal animal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('animal-${animal.tag}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: speciesColor(animal.species),
        foregroundColor: farmPaper,
        child: Text(
          _speciesMark(animal.species),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
      title: Text(
        animal.tag,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        [
          animal.species.singular,
          if (animal.stage != null) animal.stage!.label,
          animal.sex.label,
          animal.status.label,
        ].join(' · '),
      ),
      onTap: onTap,
    );
  }
}

String _speciesMark(Species species) {
  return switch (species) {
    Species.pig => 'Pi',
    Species.cattle => 'Ca',
    Species.goat => 'Go',
    Species.sheep => 'Sh',
    Species.poultry => 'Po',
  };
}

class _EmptyRegister extends StatelessWidget {
  const _EmptyRegister({required this.filtered, required this.onAdd});

  final bool filtered;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.pets, color: farmLeaf, size: 36),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Nothing on the register matches.'
                : 'No animals on the register yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtered ? 'Clear the search or choose another species.' : 'Add a pig, cow, goat, or bird with its tag, sex, and status.',
            textAlign: TextAlign.center,
          ),
          if (!filtered) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAdd,
              child: const Text('Register animal'),
            ),
          ],
        ],
      ),
    );
  }
}
