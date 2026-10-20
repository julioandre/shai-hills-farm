import 'package:flutter/material.dart';
import 'package:shai_hills_farm/app/app_backend.dart';
import 'package:shai_hills_farm/app/farm_app.dart';
import 'package:shai_hills_farm/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await AppBackend.start(AppConfig.fromEnvironment());
  runApp(FarmApp(backend: backend));
}
