/// A job an admin gives to one person on the farm.
class FarmTask {
  const FarmTask({
    required this.id,
    required this.title,
    required this.assigneeId,
    required this.createdAt,
    this.done = false,
  });

  final String id;
  final String title;
  final String assigneeId;
  final DateTime createdAt;
  final bool done;

  FarmTask copyWith({bool? done}) {
    return FarmTask(
      id: id,
      title: title,
      assigneeId: assigneeId,
      createdAt: createdAt,
      done: done ?? this.done,
    );
  }

  factory FarmTask.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];
    return FarmTask(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      assigneeId: json['assigneeId'] as String? ?? '',
      createdAt: created is String
          ? DateTime.parse(created)
          : DateTime.fromMillisecondsSinceEpoch(0),
      done: json['done'] == true,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'title': title,
    'assigneeId': assigneeId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'done': done,
  };
}
