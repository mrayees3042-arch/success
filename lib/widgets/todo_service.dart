import 'package:hive_flutter/hive_flutter.dart';

import '../models/todo_task.dart';

class TodoService {
  static const String boxName = 'todosBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TodoTaskAdapter());
    await Hive.openBox<TodoTask>(boxName);
  }

  static Box<TodoTask> get box => Hive.box<TodoTask>(boxName);

  static Future<void> addTask(String text) async {
    final task = TodoTask(title: text, createdAt: DateTime.now());
    await box.add(
      task,
    ); // 'add' generates a unique integer key instead of using 'put(id)'
  }

  static Future<void> toggleTask(TodoTask task) async {
    task.isCompleted = !task.isCompleted;
    await task.save();
  }

  static Future<void> deleteTask(TodoTask task) async {
    await task.delete();
  }
}
