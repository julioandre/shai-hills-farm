import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/herd_counts.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/species_style.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.herd,
    required this.email,
    required this.localOnly,
    this.startupNotice,
  });

  final HerdController herd;
  final String email;
  final bool localOnly;
  final String? startupNotice;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: herd,
      builder: (context, _) {
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
        final counts = HerdCounts.fromAnimals(herd.animals);
        return RefreshIndicator(
          onRefresh: () => herd.load(refresh: true),
          child: ListView(
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
              _FarmHeader(email: email, localOnly: localOnly),
              const SizedBox(height: 20),
              Text(
                'On the farm',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _CountRow(
                left: _CountCard(species: Species.pig, count: counts.pigs),
                right: _CountCard(
                  species: Species.cattle,
                  count: counts.cattle,
                ),
              ),
              const SizedBox(height: 12),
              _CountRow(
                left: _CountCard(species: Species.goat, count: counts.goats),
                right: _CountCard(
                  species: Species.poultry,
                  count: counts.poultry,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _totalSentence(counts.onFarm),
                key: const Key('count-total'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _footnote(counts, herd.animals.length),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }
}

String _totalSentence(int count) {
  if (count == 1) {
    return '1 animal on the farm';
  }
  return '$count animals on the farm';
}

String _footnote(HerdCounts counts, int recorded) {
  if (recorded == 0) {
    return 'Nothing is on the farm yet. Register the first pig, cow, goat, or bird.';
  }
  if (counts.onFarm == 0) {
    return 'No animals are marked on farm. Sold and dead records stay on the register and are left out of these counts.';
  }
  return 'Sold and dead animals stay on the register and are left out of these counts.';
}

class _FarmHeader extends StatelessWidget {
  const _FarmHeader({required this.email, required this.localOnly});

  final String email;
  final bool localOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shai Hills Farm', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Shai Hills, Ghana · 20 acres across two sites, 7 km apart',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
            const SizedBox(height: 10),
            Text('Signed in as $email', style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0EA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                localOnly ? 'On-device records' : 'Supabase',
                style: theme.textTheme.labelMedium?.copyWith(color: farmLeaf),
              ),
            ),
          ],
        ),
      ),
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
