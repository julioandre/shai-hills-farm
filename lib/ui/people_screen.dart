import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/domain/phone.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/ui/page_box.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

/// Admin list. A tap sets manager or worker. The farm keeps one admin.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  List<FarmPerson> _people = [];
  final _names = <String, TextEditingController>{};
  String? _error;
  bool _loading = true;
  int _page = 0;
  int _pageSize = 10;

  @override
  void dispose() {
    for (final controller in _names.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final people = await widget.auth.listPeople();
      if (!mounted) {
        return;
      }
      setState(() {
        _people = people;
        for (final person in people) {
          final field = _names[person.userId];
          if (field == null) {
            _names[person.userId] = TextEditingController(text: person.name);
          } else if (field.text != person.name) {
            field.text = person.name;
          }
        }
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'The people list could not be opened.';
      });
    }
  }

  Future<void> _saveName(FarmPerson person) async {
    final error = await widget.auth.setName(
      userId: person.userId,
      name: _names[person.userId]?.text ?? '',
    );
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    if (error == null) {
      await _load();
    }
  }

  Future<void> _assign(FarmPerson person, FarmRole role) async {
    final error = await widget.auth.assignRole(
      userId: person.userId,
      role: role,
    );
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    if (error == null) {
      await _load();
    }
  }

  Future<void> _assignHerds(FarmPerson person, Set<Species> herds) async {
    final stored = {...herds};
    if (stored.contains(Species.goat)) {
      stored.add(Species.sheep);
    } else {
      stored.remove(Species.sheep);
    }
    final error = await widget.auth.assignHerds(
      userId: person.userId,
      herds: stored,
    );
    if (!mounted) {
      return;
    }
    setState(() => _error = error);
    if (error == null) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: _loading
          ? const LoadingView(message: 'Loading people…')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (_error != null) ...[
                  NoticeBanner(message: _error!, isError: true),
                  const SizedBox(height: 12),
                ],
                for (final person
                    in _people.skip(_page * _pageSize).take(_pageSize))
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            person.name.trim().isEmpty
                                ? displayPhone(person.phone)
                                : person.name.trim(),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            person.name.trim().isEmpty
                                ? person.role.label
                                : '${person.role.label} · ${displayPhone(person.phone)}',
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: Key('person-name-${person.userId}'),
                            controller: _names[person.userId],
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => _saveName(person),
                            child: const Text('Save name'),
                          ),
                          if (person.role != FarmRole.admin) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                if (person.role != FarmRole.manager)
                                  OutlinedButton(
                                    onPressed: () =>
                                        _assign(person, FarmRole.manager),
                                    child: const Text('Make manager'),
                                  ),
                                if (person.role != FarmRole.worker)
                                  OutlinedButton(
                                    onPressed: () =>
                                        _assign(person, FarmRole.worker),
                                    child: const Text('Make worker'),
                                  ),
                              ],
                            ),
                            if (person.role == FarmRole.worker) ...[
                              const SizedBox(height: 12),
                              const Text('Animals they can open'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilterChip(
                                    key: Key('herd-all-${person.userId}'),
                                    label: const Text('All animals'),
                                    selected: person.herds.isEmpty,
                                    onSelected: (_) =>
                                        _assignHerds(person, const {}),
                                  ),
                                  for (final species in const [
                                    Species.pig,
                                    Species.cattle,
                                    Species.goat,
                                    Species.poultry,
                                  ])
                                    FilterChip(
                                      key: Key(
                                        'herd-${species.wire}-${person.userId}',
                                      ),
                                      label: Text(
                                        species == Species.goat
                                            ? 'Goats and sheep'
                                            : species.plural,
                                      ),
                                      selected: person.herds.contains(species),
                                      onSelected: (selected) {
                                        final next = {...person.herds};
                                        if (selected) {
                                          next.add(species);
                                        } else {
                                          next.remove(species);
                                          if (species == Species.goat) {
                                            next.remove(Species.sheep);
                                          }
                                        }
                                        if (next.isEmpty) {
                                          _assignHerds(person, const {});
                                        } else {
                                          _assignHerds(person, next);
                                        }
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                PageBar(
                  count: _people.length,
                  page: _page,
                  pageSize: _pageSize,
                  onPage: (page) => setState(() => _page = page),
                  onPageSize: (size) => setState(() {
                    _pageSize = size;
                    _page = 0;
                  }),
                ),
              ],
            ),
    );
  }
}
