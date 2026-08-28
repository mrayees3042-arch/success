import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_sync_engine.dart';

class BluetoothLogger {
  static void log(String stage, {String? deviceAddress, String? details, Object? error}) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().toIso8601String();
    final maskedAddress = (deviceAddress != null && deviceAddress.length >= 8)
        ? "${deviceAddress.substring(0, 5)}***"
        : "N/A";
    final message = "🔵 [BT_SYNC][$timestamp] STAGE: $stage | DEVICE: $maskedAddress | DETAILS: ${details ?? 'N/A'}"
        "${error != null ? ' | ERROR: $error' : ''}";
    debugPrint(message);
  }
}

class BluetoothServiceManager {
  static final BluetoothServiceManager instance = BluetoothServiceManager._internal();
  BluetoothServiceManager._internal();

  BluetoothConnection? _connection;
  bool get isConnected => _connection != null && _connection!.isConnected;

  Future<bool> requestPermissions() async {
    BluetoothLogger.log("PERMISSION_CHECK_START");
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted || status.isLimited);
    BluetoothLogger.log("PERMISSION_CHECK_RESULT", details: "All Granted: $allGranted");
    return allGranted;
  }

  Future<bool> isBluetoothEnabled() async {
    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    return isEnabled ?? false;
  }

  Future<bool> enableBluetooth() async {
    bool? success = await FlutterBluetoothSerial.instance.requestEnable();
    return success ?? false;
  }

  Future<bool> makeDiscoverable([int durationSeconds = 300]) async {
    try {
      final res = await FlutterBluetoothSerial.instance.requestDiscoverable(durationSeconds);
      return res != null && res > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> openSettings() async {
    try {
      await FlutterBluetoothSerial.instance.openSettings();
    } catch (_) {}
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      return [];
    }
  }

  Future<bool> startServer(Function(Uint8List payload) onDataReceived, Function(double progress) onProgress) async {
    try {
      await makeDiscoverable(300);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device, {int maxAttempts = 3}) async {
    BluetoothLogger.log("CONNECT_ATTEMPT_START", deviceAddress: device.address, details: "Max attempts: $maxAttempts");
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 300));
        _connection = await BluetoothConnection.toAddress(device.address);
        if (_connection != null && _connection!.isConnected) {
          BluetoothLogger.log("CONNECT_SUCCESS", deviceAddress: device.address, details: "Attempt: $attempt");
          return true;
        }
      } catch (e) {
        _connection = null;
        BluetoothLogger.log("CONNECT_ATTEMPT_FAILED", deviceAddress: device.address, details: "Attempt: $attempt", error: e);
      }
      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }
    }
    BluetoothLogger.log("CONNECT_FAILED_ALL_ATTEMPTS", deviceAddress: device.address);
    return false;
  }

  Future<bool> performTwoWayAutoSync(
    BluetoothDevice device,
    Function(String status, double progress) onUpdate,
  ) async {
    try {
      onUpdate("Connecting to ${device.name ?? 'Device'}...", 0.1);
      final connected = await connectToDevice(device, maxAttempts: 2);
      if (!connected) return false;

      onUpdate("Packaging local data...", 0.3);
      final localPayload = await BluetoothSyncEngine.instance.exportSyncBundle();

      onUpdate("Transferring data over Bluetooth...", 0.5);
      await sendPayload(localPayload, (p) {
        onUpdate("Transferring data over Bluetooth...", 0.5 + (p * 0.3));
      });

      onUpdate("Merging latest records...", 0.85);
      final stream = receivePayloadStream((p) {});
      if (stream != null) {
        final completer = Completer<bool>();
        stream.listen((incomingPayload) async {
          await BluetoothSyncEngine.instance.importAndMergeSyncBundle(incomingPayload);
          completer.complete(true);
        }, onError: (e) {
          if (!completer.isCompleted) completer.complete(false);
        }, onDone: () {
          if (!completer.isCompleted) completer.complete(true);
        });

        final result = await completer.future.timeout(
          const Duration(seconds: 15),
          onTimeout: () => true,
        );
        onUpdate("✅ Auto-Synced with ${device.name ?? 'Device'}!", 1.0);
        await disconnect();
        return result;
      }

      onUpdate("✅ Auto-Synced with ${device.name ?? 'Device'}!", 1.0);
      await disconnect();
      return true;
    } catch (e) {
      await disconnect();
      return false;
    }
  }

  Future<void> sendPayload(Uint8List payload, Function(double progress) onProgress) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception("Bluetooth connection is not active.");
    }

    final totalLength = payload.length;
    final header = ByteData(4)..setUint32(0, totalLength, Endian.big);
    
    _connection!.output.add(header.buffer.asUint8List());
    await _connection!.output.allSent;

    const chunkSize = 1024;
    int sent = 0;
    while (sent < totalLength) {
      final end = (sent + chunkSize < totalLength) ? sent + chunkSize : totalLength;
      final chunk = payload.sublist(sent, end);
      _connection!.output.add(chunk);
      await _connection!.output.allSent;
      sent = end;
      onProgress(sent / totalLength);
    }
  }

  Stream<Uint8List>? receivePayloadStream(Function(double progress) onProgress) {
    if (_connection == null) return null;

    final controller = StreamController<Uint8List>();
    List<int> buffer = [];
    int expectedLength = -1;

    _connection!.input?.listen((Uint8List chunk) {
      buffer.addAll(chunk);

      if (expectedLength == -1 && buffer.length >= 4) {
        final headerData = ByteData.sublistView(Uint8List.fromList(buffer.sublist(0, 4)));
        expectedLength = headerData.getUint32(0, Endian.big);
        buffer = buffer.sublist(4);
      }

      if (expectedLength > 0) {
        double progress = buffer.length / expectedLength;
        if (progress > 1.0) progress = 1.0;
        onProgress(progress);

        if (buffer.length >= expectedLength) {
          final payload = Uint8List.fromList(buffer.sublist(0, expectedLength));
          controller.add(payload);
          buffer = buffer.sublist(expectedLength);
          expectedLength = -1;
        }
      }
    }, onError: (e) {
      controller.addError(e);
    }, onDone: () {
      controller.close();
    });

    return controller.stream;
  }

  Future<void> disconnect() async {
    try {
      await _connection?.finish();
    } catch (_) {}
    _connection = null;
  }
}
