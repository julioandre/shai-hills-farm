import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shai_hills_farm/app/app_backend.dart';
import 'package:shai_hills_farm/domain/session.dart';
import 'package:shai_hills_farm/state/auth_controller.dart';
import 'package:shai_hills_farm/state/herd_controller.dart';
import 'package:shai_hills_farm/theme/farm_theme.dart';
import 'package:shai_hills_farm/ui/farm_frame.dart';
import 'package:shai_hills_farm/ui/home_shell.dart';
import 'package:shai_hills_farm/ui/sign_in_screen.dart';
import 'package:shai_hills_farm/ui/status_views.dart';

class FarmApp extends StatefulWidget {
  const FarmApp({super.key, required this.backend});

  final AppBackend backend;

  @override
  State<FarmApp> createState() => _FarmAppState();
}

class _FarmAppState extends State<FarmApp> {
  late final AuthController auth;
  late final HerdController herd;
  FarmSession? _loadedFor;

  @override
  void initState() {
    super.initState();
    auth = AuthController(widget.backend.auth);
    herd = HerdController(widget.backend.animals);
    auth.addListener(_syncHerd);
    unawaited(auth.restore());
  }

  void _syncHerd() {
    final session = auth.session;
    if (session == null) {
      _loadedFor = null;
      herd.clear();
      return;
    }
    if (_loadedFor?.userId != session.userId) {
      _loadedFor = session;
      unawaited(herd.load());
    }
  }

  @override
  void dispose() {
    auth.removeListener(_syncHerd);
    auth.dispose();
    herd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shai Hills Farm',
      debugShowCheckedModeBanner: false,
      theme: farmTheme(),
      scrollBehavior: const FarmScrollBehavior(),
      builder: (context, child) {
        return FarmFrame(child: child ?? const SizedBox.shrink());
      },
      home: ListenableBuilder(
        listenable: auth,
        builder: (context, _) {
          if (auth.restoring) {
            return const Scaffold(
              body: LoadingView(message: 'Checking for a saved sign-in…'),
            );
          }
          if (auth.session == null) {
            return SignInScreen(
              auth: auth,
              localOnly: widget.backend.localOnly,
              startupNotice: widget.backend.startupNotice,
            );
          }
          return HomeShell(
            auth: auth,
            herd: herd,
            localOnly: widget.backend.localOnly,
            startupNotice: widget.backend.startupNotice,
          );
        },
      ),
    );
  }
}
