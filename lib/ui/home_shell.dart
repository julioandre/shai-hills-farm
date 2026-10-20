import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/ui/animal_form_screen.dart';
import 'package:shai_hills_farm/ui/dashboard_screen.dart';
import 'package:shai_hills_farm/ui/registry_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.auth,
    required this.herd,
    required this.localOnly,
    this.startupNotice,
  });

  final AuthController auth;
  final HerdController herd;
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
          content: const Text('The herd stays saved for this account.'),
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

  void _openNewAnimal() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AnimalFormScreen(herd: widget.herd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.auth.session;
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'Dashboard' : 'Register'),
        actions: [
          PopupMenuButton<String>(
            key: const Key('account-menu'),
            tooltip: 'Account',
            onSelected: (value) {
              if (value == 'sign-out') {
                unawaited(_signOut());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                key: const Key('sign-out-menu'),
                value: 'sign-out',
                child: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(
            herd: widget.herd,
            email: session?.email ?? '',
            localOnly: widget.localOnly,
            startupNotice: widget.startupNotice,
          ),
          RegistryScreen(herd: widget.herd),
        ],
      ),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              key: const Key('add-animal'),
              onPressed: _openNewAnimal,
              icon: const Icon(Icons.add),
              label: const Text('Register animal'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            key: Key('nav-dashboard'),
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            key: Key('nav-register'),
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Register',
          ),
        ],
      ),
    );
  }
}
