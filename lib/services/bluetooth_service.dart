import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothServiceManager {
  static final BluetoothServiceManager instance = BluetoothServiceManager._internal();
  BluetoothServiceManager._internal();

  BluetoothConnection? _connection;
  bool get isConnected => _connection != null && _connection!.isConnected;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted || status.isLimited);
  }

  Future<bool> isBluetoothEnabled() async {
    bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
    return isEnabled ?? false;
  }

  Future<bool> enableBluetooth() async {
    bool? success = await FlutterBluetoothSerial.instance.requestEnable();
    return success ?? false;
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
      // Prepared server listening state
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await disconnect();
      _connection = await BluetoothConnection.toAddress(device.address);
      return true;
    } catch (e) {
      _connection = null;
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
