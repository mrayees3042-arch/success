import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../app_theme.dart'; // Access your ThemeColors & kTeal
import '../models/todo_task.dart';
import 'package:success/services/todo_service.dart';
import '../widgets/todo_tile.dart';

class TodoScreen extends StatefulWidget {
  const TodoScreen({super.key, required this.theme});
  final ThemeColors theme;

  @override
  State<TodoScreen> createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  final TextEditingController _ctrl = TextEditingController();

  void _add() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    await TodoService.addTask(text);

    if (!mounted) return;

    _ctrl.clear();
    FocusScope.of(context).unfocus(); // dismiss keyboard
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Text(
              'To-Do',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: theme.text1,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    style: TextStyle(color: theme.text1),
                    decoration: InputDecoration(
                      hintText: 'Add a new task...',
                      hintStyle: TextStyle(color: theme.text4),
                      filled: true,
                      fillColor: theme.card,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.border, width: 0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.border, width: 0.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: kTeal, width: 1),
                      ),
                    ),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _add,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kTeal,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kTeal.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<Box<TodoTask>>(
              valueListenable: TodoService.box.listenable(),
              builder: (context, box, _) {
                if (box.values.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: theme.border,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You\'re all caught up!',
                          style: TextStyle(
                            color: theme.text3,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add a task above to get started',
                          style: TextStyle(color: theme.text4, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final todos = box.values.toList().cast<TodoTask>();
                // Sort uncompleted first, then by creation date (newest first)
                todos.sort((a, b) {
                  if (a.isCompleted == b.isCompleted) {
                    return b.createdAt.compareTo(a.createdAt);
                  }
                  return a.isCompleted ? 1 : -1;
                });

                return ListView.builder(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            cacheExtent: 1000,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: todos.length,
                  itemBuilder: (_, i) {
                    final todo = todos[i];
                    return RepaintBoundary(
                      child: TodoTile(
                        key: ValueKey(todo.key),
                        task: todo,
                        theme: theme,
                        onToggle: () {
                          HapticFeedback.lightImpact();
                          TodoService.toggleTask(todo);
                        },
                        onDelete: () {
                          HapticFeedback.mediumImpact();
                          TodoService.deleteTask(todo);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
