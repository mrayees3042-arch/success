import 'dart:convert';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BluetoothSyncEngine {
  static final BluetoothSyncEngine instance = BluetoothSyncEngine._internal();
  BluetoothSyncEngine._internal();

  Future<Uint8List> exportSyncBundle() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> prefData = {};

    for (String key in prefs.getKeys()) {
      prefData[key] = prefs.get(key);
    }

    final Map<String, dynamic> hiveData = {};
    if (Hive.isBoxOpen('todosBox')) {
      final box = Hive.box('todosBox');
      final Map<String, dynamic> todos = {};
      for (var key in box.keys) {
        todos[key.toString()] = box.get(key);
      }
      hiveData['todosBox'] = todos;
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
      
      final backupMap = {};
      for (String k in prefs.getKeys()) {
        backupMap[k] = prefs.get(k);
      }
      await prefs.setString('bluetooth_last_backup_at', DateTime.now().toUtc().toIso8601String());

      if (payload.containsKey('shared_preferences')) {
        final Map<String, dynamic> incomingPrefs = payload['shared_preferences'];
        
        incomingPrefs.forEach((key, incomingVal) {
          if (incomingVal == null) return;

          final existingVal = prefs.get(key);
          if (existingVal == null) {
            _setPrefValue(prefs, key, incomingVal);
          } else if (key.endsWith('_updated_at')) {
            _setPrefValue(prefs, key, incomingVal);
          } else {
            final String timeKey = '${key}_updated_at';
            final incomingTime = incomingPrefs[timeKey] as String?;
            final existingTime = prefs.getString(timeKey);

            if (incomingTime != null && existingTime != null) {
              final incDT = DateTime.tryParse(incomingTime);
              final exDT = DateTime.tryParse(existingTime);
              if (incDT != null && exDT != null && incDT.isAfter(exDT)) {
                _setPrefValue(prefs, key, incomingVal);
              }
            } else {
              _setPrefValue(prefs, key, incomingVal);
            }
          }
        });
      }

      if (payload.containsKey('hive_boxes')) {
        final Map<String, dynamic> hiveBoxes = payload['hive_boxes'];
        if (hiveBoxes.containsKey('todosBox') && Hive.isBoxOpen('todosBox')) {
          final box = Hive.box('todosBox');
          final Map<String, dynamic> incomingTodos = hiveBoxes['todosBox'];
          incomingTodos.forEach((k, v) {
            box.put(k, v);
          });
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
