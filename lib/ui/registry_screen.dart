import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/animal_form_screen.dart';
import 'package:shai_hills_farm/ui/species_style.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class RegistryScreen extends StatefulWidget {
  const RegistryScreen({super.key, required this.herd});

  final HerdController herd;

  @override
  State<RegistryScreen> createState() => _RegistryScreenState();
}

class _RegistryScreenState extends State<RegistryScreen> {
  String _query = '';
  Species? _species;

  void _openForm([Animal? animal]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            AnimalFormScreen(herd: widget.herd, animal: animal),
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
        final visible = [
          for (final animal in herd.animals)
            if (_matches(animal)) animal,
        ];
        return Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => herd.load(refresh: true),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: [
                    if (herd.refreshError != null) ...[
                      NoticeBanner(message: herd.refreshError!, isError: true),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      key: const Key('search-tag'),
                      decoration: const InputDecoration(
                        hintText: 'Search tag or ID',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setState(() => _query = value),
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
                          onSelected: (_) => setState(() => _species = null),
                        ),
                        for (final species in Species.values)
                          FilterChip(
                            key: Key('filter-${species.wire}'),
                            label: Text(species.plural),
                            selected: _species == species,
                            onSelected: (_) =>
                                setState(() => _species = species),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      _EmptyRegister(
                        filtered: herd.animals.isNotEmpty,
                        onAdd: () => _openForm(),
                      )
                    else
                      Card(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < visible.length;
                              index++
                            ) ...[
                              if (index > 0) const Divider(height: 1),
                              _AnimalTile(
                                animal: visible[index],
                                onTap: () => _openForm(visible[index]),
                              ),
                            ],
                          ],
                        ),
                      ),
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
        '${animal.species.singular} · ${animal.sex.label} · ${animal.status.label}',
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
