import 'package:hive/hive.dart';

part 'todo_task.g.dart';

@HiveType(typeId: 0)
class TodoTask extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  bool isCompleted;

  @HiveField(2)
  DateTime createdAt;

  TodoTask({
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
  });
}
