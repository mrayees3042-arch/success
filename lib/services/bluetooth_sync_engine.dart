import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_task.dart';

class BluetoothSyncEngine {
  static final BluetoothSyncEngine instance = BluetoothSyncEngine._internal();
  BluetoothSyncEngine._internal();

  /// Export all application data to a shareable JSON backup file and open Android System Share (Bluetooth/Nearby)
  Future<bool> exportAndShareDataFile() async {
    try {
      final rawBytes = await exportSyncBundle();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/muttaqin_data_backup.json';
      final file = File(filePath);
      await file.writeAsBytes(rawBytes);

      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'application/json')],
        text: 'Muttaqin App Data File Backup (Send via Bluetooth / Nearby)',
        subject: 'Muttaqin Data Backup',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Let user pick a received data backup file (.json) and merge into local database
  Future<bool> importDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final rawBytes = await file.readAsBytes();
        return await importAndMergeSyncBundle(rawBytes);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<Uint8List> exportSyncBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> prefData = {};

    for (String key in prefs.getKeys()) {
      prefData[key] = prefs.get(key);
    }

    final Map<String, dynamic> hiveData = {};
    if (Hive.isBoxOpen('todosBox')) {
      final box = Hive.box<TodoTask>('todosBox');
      final List<Map<String, dynamic>> todosList = [];
      for (var task in box.values) {
        todosList.add({
          'title': task.title,
          'isCompleted': task.isCompleted,
          'createdAt': task.createdAt.toUtc().toIso8601String(),
        });
      }
      hiveData['todosBox'] = todosList;
    }

    final payloadMap = {
      'schema_version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'shared_preferences': prefData,
      'hive_boxes': hiveData,
    };

    final jsonString = jsonEncode(payloadMap);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  Future<bool> importAndMergeSyncBundle(Uint8List rawPayload) async {
    try {
      final jsonString = utf8.decode(rawPayload);
      final Map<String, dynamic> payload = jsonDecode(jsonString);

      final prefs = await SharedPreferences.getInstance();
      
      // Save local backup timestamp
      await prefs.setString('bluetooth_last_backup_at', DateTime.now().toUtc().toIso8601String());

      // 1. Merge SharedPreferences (100% coverage across all user data)
      if (payload.containsKey('shared_preferences')) {
        final Map<String, dynamic> incomingPrefs = Map<String, dynamic>.from(payload['shared_preferences']);
        
        incomingPrefs.forEach((key, incomingVal) {
          if (incomingVal == null) return;
          _setPrefValue(prefs, key, incomingVal);
        });
      }

      // 2. Merge Hive todosBox (100% coverage across all todo tasks)
      if (payload.containsKey('hive_boxes')) {
        final Map<String, dynamic> hiveBoxes = Map<String, dynamic>.from(payload['hive_boxes']);
        if (hiveBoxes.containsKey('todosBox') && Hive.isBoxOpen('todosBox')) {
          final box = Hive.box<TodoTask>('todosBox');
          final List incomingTodos = hiveBoxes['todosBox'] as List;

          final existingTasksMap = <String, TodoTask>{};
          for (var t in box.values) {
            final key = '${t.title}_${t.createdAt.toUtc().toIso8601String()}';
            existingTasksMap[key] = t;
          }

          for (var item in incomingTodos) {
            if (item is Map) {
              final Map<String, dynamic> taskMap = Map<String, dynamic>.from(item);
              final String title = taskMap['title'] ?? '';
              final bool isCompleted = taskMap['isCompleted'] ?? false;
              final String createdAtStr = taskMap['createdAt'] ?? '';
              final DateTime createdAt = DateTime.tryParse(createdAtStr) ?? DateTime.now();

              final taskKey = '${title}_${createdAt.toUtc().toIso8601String()}';

              if (title.isNotEmpty) {
                if (existingTasksMap.containsKey(taskKey)) {
                  final existing = existingTasksMap[taskKey]!;
                  existing.isCompleted = isCompleted;
                  await existing.save();
                } else {
                  final newTask = TodoTask(
                    title: title,
                    isCompleted: isCompleted,
                    createdAt: createdAt,
                  );
                  await box.add(newTask);
                }
              }
            }
          }
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  void _setPrefValue(SharedPreferences prefs, String key, dynamic value) {
    if (value is bool) {
      prefs.setBool(key, value);
    } else if (value is int) {
      prefs.setInt(key, value);
    } else if (value is double) {
      prefs.setDouble(key, value);
    } else if (value is String) {
      prefs.setString(key, value);
    } else if (value is List) {
      prefs.setStringList(key, value.cast<String>());
    }
  }
}
