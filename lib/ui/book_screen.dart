import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/farm_entry.dart';
import 'package:shai_hills_farm/state/book_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({
    super.key,
    required this.book,
    required this.onAdd,
    this.herd,
    this.showMoney = true,
    this.allowedSpecies = const [],
  });

  final BookController book;
  final HerdController? herd;
  final VoidCallback onAdd;
  final bool showMoney;

  /// Empty means every note. Otherwise hide notes tied to another herd.
  final List<Species> allowedSpecies;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  String _query = '';
  String? _actionError;

  Future<void> _openEntry(FarmEntry entry) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(entryTitle(entry)),
          content: Text('${formatFarmDate(entry.happenedOn)}\n\n${entry.note}'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Close'),
            ),
            TextButton(
              key: const Key('confirm-remove-entry'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (remove != true || !mounted) {
      return;
    }
    final error = await widget.book.remove(entry.id);
    if (!mounted) {
      return;
    }
    setState(() => _actionError = error);
  }

  @override
  Widget build(BuildContext context) {
    final herd = widget.herd;
    if (herd == null) {
      return _page(const []);
    }
    return ListenableBuilder(
      listenable: herd,
      builder: (context, _) => _page(herd.animals),
    );
  }

  Widget _page(List<Animal> animals) {
    return ListenableBuilder(
      listenable: widget.book,
      builder: (context, _) {
        final book = widget.book;
        if (book.loading && book.entries.isEmpty) {
          return const LoadingView(message: 'Loading the book…');
        }
        if (book.error != null && book.entries.isEmpty) {
          return ErrorView(
            title: 'The book could not be opened',
            message: book.error!,
            onRetry: () => book.load(),
          );
        }
        final visible = [
          for (final entry in book.entries)
            if (_allowed(entry, animals) && _matches(entry)) entry,
        ];
        return RefreshIndicator(
          onRefresh: () => book.load(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              if (_actionError != null) ...[
                NoticeBanner(message: _actionError!, isError: true),
                const SizedBox(height: 12),
              ],
              if (book.refreshError != null) ...[
                NoticeBanner(message: book.refreshError!, isError: true),
                const SizedBox(height: 12),
              ],
              Text(
                widget.showMoney
                    ? 'A notebook of short notes: feed, health, breeding, milk, a sale, or a death. Search it later. A sale or a death also takes that animal off the farm counts.'
                    : 'A notebook of short notes: feed, health, breeding, milk, or a death. Search it later. A death also takes that animal off the farm counts.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('search-book'),
                decoration: const InputDecoration(
                  hintText: 'Search notes or tags',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 16),
              if (visible.isEmpty)
                _EmptyBook(
                  filtered: book.entries.isNotEmpty,
                  onAdd: widget.onAdd,
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var index = 0; index < visible.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _EntryTile(
                          entry: visible[index],
                          onTap: () => _openEntry(visible[index]),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _allowed(FarmEntry entry, List<Animal> animals) {
    if (widget.allowedSpecies.isEmpty) {
      return true;
    }
    final tag = entry.animalTag;
    if (tag == null || tag.isEmpty) {
      return true;
    }
    for (final animal in animals) {
      if (animal.tag == tag) {
        return widget.allowedSpecies.contains(animal.species);
      }
    }
    return true;
  }

  bool _matches(FarmEntry entry) {
    if (!widget.showMoney && entry.kind == BookKind.sale) {
      return false;
    }
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    final tag = entry.animalTag?.toLowerCase() ?? '';
    return entry.note.toLowerCase().contains(query) ||
        tag.contains(query) ||
        entry.kind.label.toLowerCase().contains(query);
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onTap});

  final FarmEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      key: Key('entry-${entry.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: farmLeaf,
        foregroundColor: farmPaper,
        child: Icon(_kindIcon(entry.kind), size: 20),
      ),
      title: Text(
        entryTitle(entry),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text('${formatFarmDate(entry.happenedOn)} · ${entry.note}'),
      onTap: onTap,
    );
  }
}

IconData _kindIcon(BookKind kind) {
  return switch (kind) {
    BookKind.health => Icons.healing,
    BookKind.feed => Icons.grass,
    BookKind.breeding => Icons.favorite_border,
    BookKind.milk => Icons.water_drop_outlined,
    BookKind.sale => Icons.payments_outlined,
    BookKind.death => Icons.heart_broken_outlined,
  };
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook({required this.filtered, required this.onAdd});

  final bool filtered;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(Icons.menu_book_outlined, color: farmLeaf, size: 36),
          const SizedBox(height: 12),
          Text(
            filtered
                ? 'Nothing in the book matches.'
                : 'Nothing in the book yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Clear the search.'
                : 'Write feed, health, milk, breeding, a sale, or a death.',
            textAlign: TextAlign.center,
          ),
          if (!filtered) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAdd,
              child: const Text('Write in the book'),
            ),
          ],
        ],
      ),
    );
  }
}
