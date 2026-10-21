import 'dart:convert';

import 'package:shai_hills_farm/data/key_value_store.dart';
import 'package:shai_hills_farm/domain/farm_task.dart';

const _tasksKey = 'shai_hills.tasks';

/// Tasks stay on this phone and are shared by the people who sign in here.
class LocalTaskRepository {
  LocalTaskRepository(this._store);

  final KeyValueStore _store;

  Future<List<FarmTask>> list() async {
    final raw = await _store.read(_tasksKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is Map) FarmTask.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> saveAll(List<FarmTask> tasks) {
    return _store.write(
      _tasksKey,
      jsonEncode([for (final task in tasks) task.toJson()]),
    );
  }
}
