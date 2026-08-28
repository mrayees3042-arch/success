import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/todo_task.dart';

class ImportResult {
  final bool success;
  final String message;
  final int prefsCount;
  final int nativeStorageCount;
  final int todosCount;

  ImportResult({
    required this.success,
    required this.message,
    this.prefsCount = 0,
    this.nativeStorageCount = 0,
    this.todosCount = 0,
  });
}

class BluetoothSyncEngine {
  static final BluetoothSyncEngine instance = BluetoothSyncEngine._internal();
  BluetoothSyncEngine._internal();

  static const MethodChannel _nativeChannel = MethodChannel('rayees.history/storage');

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
  Future<ImportResult> importDataFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final rawBytes = await file.readAsBytes();
        return await importAndMergeSyncBundle(rawBytes);
      }
      return ImportResult(
        success: false,
        message: "No file selected or import cancelled.",
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: "Import error: ${e.toString()}",
      );
    }
  }

  Future<Uint8List> exportSyncBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> prefData = {};

    for (String key in prefs.getKeys()) {
      prefData[key] = prefs.get(key);
    }

    // Export Native Android Storage (rayees_history: history_v2, income_log_v1, expense_log_v1, water_*)
    final Map<String, dynamic> nativeStorageData = {};
    try {
      final Map<dynamic, dynamic>? nativeAll = await _nativeChannel.invokeMethod('getAll');
      if (nativeAll != null) {
        nativeAll.forEach((key, value) {
          if (key != null && value != null) {
            nativeStorageData[key.toString()] = value.toString();
          }
        });
      }
    } catch (_) {}

    // Export Hive todosBox
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
      'app_name': 'Muttaqin',
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'shared_preferences': prefData,
      'native_storage': nativeStorageData,
      'hive_boxes': hiveData,
    };

    // Offload JSON serialization to background isolate via compute
    final jsonString = await compute(_encodeJsonIso, payloadMap);
    return Uint8List.fromList(utf8.encode(jsonString));
  }

  Future<ImportResult> importAndMergeSyncBundle(Uint8List rawPayload) async {
    if (rawPayload.isEmpty) {
      return ImportResult(
        success: false,
        message: "Failed: Received data file is empty (0 bytes).",
      );
    }

    try {
      final jsonString = utf8.decode(rawPayload);
      // Offload JSON parsing to background isolate via compute
      final Map<String, dynamic> payload = await compute(_decodeJsonIso, jsonString);

      if (!payload.containsKey('schema_version')) {
        return ImportResult(
          success: false,
          message: "Failed: Invalid or corrupt backup file schema.",
        );
      }

      int prefCount = 0;
      int nativeCount = 0;
      int todoCount = 0;

      final prefs = await SharedPreferences.getInstance();

      // 1. Merge Standard SharedPreferences with strict async writes
      if (payload.containsKey('shared_preferences')) {
        final Map<String, dynamic> incomingPrefs = Map<String, dynamic>.from(payload['shared_preferences']);

        for (var entry in incomingPrefs.entries) {
          if (entry.value != null) {
            final ok = await _setPrefValue(prefs, entry.key, entry.value);
            if (ok) prefCount++;
          }
        }
        await prefs.reload();
      }

      // Save local backup timestamp
      await prefs.setString('bluetooth_last_backup_at', DateTime.now().toUtc().toIso8601String());

      // 2. Merge Native Android Storage (history_v2, income_log_v1, expense_log_v1, water_*)
      if (payload.containsKey('native_storage')) {
        final Map<String, dynamic> incomingNative = Map<String, dynamic>.from(payload['native_storage']);
        final Map<String, String> nativePayload = {};

        incomingNative.forEach((key, val) {
          if (val != null) {
            nativePayload[key] = val.toString();
          }
        });

        if (nativePayload.isNotEmpty) {
          try {
            final bool? ok = await _nativeChannel.invokeMethod('setAll', nativePayload);
            if (ok == true) {
              nativeCount = nativePayload.length;
            }
          } catch (_) {}
        }
      }

      // 3. Merge Hive todosBox
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
                  todoCount++;
                } else {
                  final newTask = TodoTask(
                    title: title,
                    isCompleted: isCompleted,
                    createdAt: createdAt,
                  );
                  await box.add(newTask);
                  todoCount++;
                }
              }
            }
          }
        }
      }

      return ImportResult(
        success: true,
        message: "Data was received and imported successfully! ($prefCount settings, $nativeCount logs, $todoCount tasks committed)",
        prefsCount: prefCount,
        nativeStorageCount: nativeCount,
        todosCount: todoCount,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        message: "Data import failed: ${e.toString()}",
      );
    }
  }

  Future<bool> _setPrefValue(SharedPreferences prefs, String key, dynamic value) async {
    if (value is bool) {
      return await prefs.setBool(key, value);
    } else if (value is int) {
      return await prefs.setInt(key, value);
    } else if (value is double) {
      return await prefs.setDouble(key, value);
    } else if (value is String) {
      return await prefs.setString(key, value);
    } else if (value is List) {
      return await prefs.setStringList(key, value.cast<String>());
    }
    return false;
  }
}

// Global top-level functions for compute isolates
String _encodeJsonIso(Map<String, dynamic> data) => jsonEncode(data);
Map<String, dynamic> _decodeJsonIso(String jsonStr) => jsonDecode(jsonStr) as Map<String, dynamic>;
