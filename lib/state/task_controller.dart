import 'package:flutter/foundation.dart';
import 'package:shai_hills_farm/data/local_task_repository.dart';
import 'package:shai_hills_farm/domain/farm_task.dart';
import 'package:shai_hills_farm/domain/ids.dart';

class TaskController extends ChangeNotifier {
  TaskController(this._repository);

  final LocalTaskRepository _repository;

  List<FarmTask> tasks = [];

  Future<void> load() async {
    tasks = [...await _repository.list()]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  void clear() {
    tasks = [];
    notifyListeners();
  }

  Future<String?> add({
    required String title,
    required String assigneeId,
  }) async {
    final text = title.trim();
    if (text.isEmpty) {
      return 'Write what needs doing.';
    }
    if (assigneeId.isEmpty) {
      return 'Choose who will do it.';
    }
    tasks = [
      FarmTask(
        id: newId(),
        title: text,
        assigneeId: assigneeId,
        createdAt: DateTime.now().toUtc(),
      ),
      ...tasks,
    ];
    await _repository.saveAll(tasks);
    notifyListeners();
    return null;
  }

  Future<void> setDone(String id, bool done) async {
    tasks = [
      for (final task in tasks)
        if (task.id == id) task.copyWith(done: done) else task,
    ];
    await _repository.saveAll(tasks);
    notifyListeners();
  }
}
