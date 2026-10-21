import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shai_hills_farm/domain/animal.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/state/book_controller.dart';
import 'package:shai_hills_farm/domain/role.dart';
import 'package:shai_hills_farm/state/feed_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/state/ledger_controller.dart';
import 'package:shai_hills_farm/state/task_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/animal_form_screen.dart';
import 'package:shai_hills_farm/ui/charts_screen.dart';
import 'package:shai_hills_farm/ui/dashboard_screen.dart';
import 'package:shai_hills_farm/ui/farm_logo.dart';
import 'package:shai_hills_farm/ui/feed_screen.dart';
import 'package:shai_hills_farm/ui/money_screen.dart';
import 'package:shai_hills_farm/ui/people_screen.dart';
import 'package:shai_hills_farm/ui/registry_screen.dart';
import 'package:shai_hills_farm/ui/today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.herd,
    required this.book,
    required this.ledger,
    required this.feed,
    required this.tasks,
    required this.localOnly,
    this.startupNotice,
  });

  final AuthController auth;
  final HerdController herd;
  final BookController book;
  final LedgerController ledger;
  final FeedController feed;
  final TaskController tasks;
  final bool localOnly;
  final String? startupNotice;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sign out?'),
          content: const Text(
            'The herd and the book stay saved for this account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay signed in'),
            ),
            FilledButton(
              key: const Key('confirm-sign-out'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sign out'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await widget.auth.signOut();
  }

  void _openPeople() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PeopleScreen(auth: widget.auth),
      ),
    );
  }

  void _openNewAnimal({AnimalStatus? status, Species? species}) {
    final access =
        widget.auth.session?.access ?? const FarmAccess(FarmRole.worker);
    final choices = access.speciesChoices;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AnimalFormScreen(
          herd: widget.herd,
          ledger: widget.ledger.ledger,
          initialStatus: status,
          initialSpecies:
              species ?? (choices.length == 1 ? choices.first : null),
          speciesChoices: choices,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.auth.session;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final role = session?.role ?? FarmRole.worker;
        final herds = session?.herds ?? const <Species>{};
        final access = FarmAccess(role, herds: herds);
        final showMoney = access.viewFinancials;
        final pages = <Widget>[
          DashboardScreen(
            herd: widget.herd,
            book: widget.book,
            ledger: widget.ledger,
            tasks: widget.tasks,
            auth: widget.auth,
            phone: session?.phone ?? '',
            userId: session?.userId ?? '',
            role: role,
            herds: herds,
            startupNotice: widget.startupNotice,
          ),
          TodayScreen(
            ledger: widget.ledger,
            role: role,
            herds: herds,
            localOnly: widget.localOnly,
            onRegister: ({AnimalStatus? status, Species? species}) =>
                _openNewAnimal(status: status, species: species),
          ),
          ChartsScreen(
            herd: widget.herd,
            ledger: widget.ledger,
            feed: widget.feed,
            showMoney: showMoney,
            workerView: role == FarmRole.worker,
            herds: herds,
          ),
          RegistryScreen(
            herd: widget.herd,
            ledger: widget.ledger.ledger,
            speciesChoices: access.speciesChoices,
          ),
          FeedScreen(
            feed: widget.feed,
            ledger: widget.ledger,
            showMoney: showMoney,
            canManage: access.manageFeedPurchases,
            speciesChoices: access.speciesChoices,
            limitedCharts: role == FarmRole.worker,
          ),
          if (showMoney)
            MoneyScreen(
              ledger: widget.ledger,
              feed: widget.feed,
              herd: widget.herd,
            ),
        ];
        const recordIndex = 1;
        const chartsIndex = 2;
        const animalIndex = 3;
        const feedIndex = 4;
        final moneyIndex = showMoney ? 5 : -1;
        final index = _index >= pages.length ? 0 : _index;
        final title = switch (index) {
          0 => 'Home',
          recordIndex => 'Record',
          chartsIndex => 'Charts',
          animalIndex => 'Animals',
          feedIndex => 'Feed',
          _ when index == moneyIndex => 'Money',
          _ => 'Home',
        };
        void openPage(int page) => setState(() => _index = page);
        final stack = IndexedStack(index: index, children: pages);
        final accountMenu = PopupMenuButton<String>(
          key: const Key('account-menu'),
          tooltip: 'Account',
          onSelected: (value) {
            if (value == 'people') {
              _openPeople();
            }
            if (value == 'sign-out') {
              unawaited(_signOut());
            }
          },
          itemBuilder: (context) => [
            if (access.manageUsers)
              const PopupMenuItem(
                key: Key('people-menu'),
                value: 'people',
                child: Text('People'),
              ),
            const PopupMenuItem(
              key: Key('sign-out-menu'),
              value: 'sign-out',
              child: Text('Sign out'),
            ),
          ],
        );
        AppBar appBar({required bool includeLogo}) {
          return AppBar(
            automaticallyImplyLeading: false,
            titleSpacing: 16,
            title: includeLogo
                ? Row(
                    children: [
                      const FarmLogo(width: 36),
                      const SizedBox(width: 12),
                      Text(title),
                    ],
                  )
                : Text(title),
            actions: [accountMenu],
          );
        }

        final registerButton = index == animalIndex
            ? FloatingActionButton.extended(
                key: const Key('add-animal'),
                onPressed: _openNewAnimal,
                icon: const Icon(Icons.add),
                label: const Text('Register animal'),
              )
            : null;
        if (wide) {
          return Scaffold(
            floatingActionButton: registerButton,
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FarmRail(
                  index: index,
                  showMoney: showMoney,
                  onSelected: openPage,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    children: [
                      appBar(includeLogo: false),
                      Expanded(child: stack),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          appBar: appBar(includeLogo: true),
          body: stack,
          floatingActionButton: registerButton,
          bottomNavigationBar: _PhoneBar(
            index: index,
            showMoney: showMoney,
            onSelected: openPage,
          ),
        );
      },
    );
  }
}

class _FarmRail extends StatelessWidget {
  const _FarmRail({
    required this.index,
    required this.showMoney,
    required this.onSelected,
  });

  final int index;
  final bool showMoney;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: farmPaper,
      child: SizedBox(
        width: 104,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
              child: FarmLogo(width: 84),
            ),
            Expanded(
              child: NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelected,
                labelType: NavigationRailLabelType.all,
                backgroundColor: farmPaper,
                minWidth: 88,
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: Text('Home'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.edit_note_outlined),
                    selectedIcon: Icon(Icons.edit_note),
                    label: Text('Record'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_outlined),
                    selectedIcon: Icon(Icons.bar_chart),
                    label: Text('Charts'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.pets_outlined),
                    selectedIcon: Icon(Icons.pets),
                    label: Text('Animals'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.grass_outlined),
                    selectedIcon: Icon(Icons.grass),
                    label: Text('Feed'),
                  ),
                  if (showMoney)
                    const NavigationRailDestination(
                      icon: Icon(Icons.payments_outlined),
                      selectedIcon: Icon(Icons.payments),
                      label: Text('Money'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneBar extends StatelessWidget {
  const _PhoneBar({
    required this.index,
    required this.showMoney,
    required this.onSelected,
  });

  final int index;
  final bool showMoney;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <({int page, Key key, IconData icon, String label})>[
      (
        page: 0,
        key: const Key('nav-dashboard'),
        icon: Icons.home_outlined,
        label: 'Home',
      ),
      (
        page: 1,
        key: const Key('nav-today'),
        icon: Icons.edit_note,
        label: 'Record',
      ),
      (
        page: 2,
        key: const Key('nav-charts'),
        icon: Icons.bar_chart,
        label: 'Charts',
      ),
      (
        page: 3,
        key: const Key('nav-register'),
        icon: Icons.pets,
        label: 'Animals',
      ),
      (page: 4, key: const Key('nav-feed'), icon: Icons.grass, label: 'Feed'),
      if (showMoney)
        (
          page: 5,
          key: const Key('nav-money'),
          icon: Icons.payments,
          label: 'Money',
        ),
    ];
    return Material(
      color: farmPaper,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (final item in items)
                Expanded(
                  child: InkWell(
                    key: item.key,
                    onTap: () => onSelected(item.page),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 22,
                          color: index == item.page ? farmLeaf : farmInk,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: index == item.page
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: index == item.page ? farmLeaf : farmInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
