import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:success/core/app_fonts.dart';
import 'package:success/services/bluetooth_service.dart';
import 'package:success/services/bluetooth_sync_engine.dart';

class BluetoothSyncSheet extends StatefulWidget {
  const BluetoothSyncSheet({super.key});

  @override
  State<BluetoothSyncSheet> createState() => _BluetoothSyncSheetState();
}

enum SyncRole { none, host, receiver }

class _BluetoothSyncSheetState extends State<BluetoothSyncSheet> {
  SyncRole _role = SyncRole.none;
  bool _isPermissionGranted = false;
  bool _isBluetoothEnabled = false;
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isSyncing = false;
  double _progress = 0.0;
  String _statusMessage = "Select Host or Receiver mode to begin.";

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    final granted = await BluetoothServiceManager.instance.requestPermissions();
    final enabled = await BluetoothServiceManager.instance.isBluetoothEnabled();

    setState(() {
      _isPermissionGranted = granted;
      _isBluetoothEnabled = enabled;
    });

    if (granted && enabled) {
      _loadPairedDevices();
    }
  }

  Future<void> _loadPairedDevices() async {
    final devices = await BluetoothServiceManager.instance.getPairedDevices();
    setState(() {
      _pairedDevices = devices;
    });
  }

  Future<void> _startHostMode() async {
    setState(() {
      _role = SyncRole.host;
      _isSyncing = true;
      _progress = 0.1;
      _statusMessage = "📡 Host Mode Active (Discoverable). On the second phone, open Bluetooth Sync and tap SYNC.";
    });

    final success = await BluetoothServiceManager.instance.startServer(
      (Uint8List payload) async {
        setState(() {
          _statusMessage = "Receiving incoming sync bundle...";
        });
        final merged = await BluetoothSyncEngine.instance.importAndMergeSyncBundle(payload);
        if (merged) {
          final replyPayload = await BluetoothSyncEngine.instance.exportSyncBundle();
          await BluetoothServiceManager.instance.sendPayload(replyPayload, (p) {
            setState(() => _progress = p);
          });
          setState(() {
            _isSyncing = false;
            _progress = 1.0;
            _statusMessage = "✅ Offline Sync Complete! All data synchronized.";
          });
        }
      },
      (double p) {
        setState(() => _progress = p);
      },
    );

    if (!success) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "Failed to start Bluetooth host discoverability.";
      });
    }
  }

  Future<void> _startReceiverMode(BluetoothDevice device) async {
    setState(() {
      _role = SyncRole.receiver;
      _selectedDevice = device;
      _isSyncing = true;
      _progress = 0.05;
      _statusMessage = "Connecting to ${device.name ?? 'Device'} (Attempting 1 of 3)...";
    });

    final connected = await BluetoothServiceManager.instance.connectToDevice(device, maxAttempts: 3);
    if (!connected) {
      setState(() {
        _isSyncing = false;
        _statusMessage = "❌ Could not connect to ${device.name ?? 'Device'}. Ensure ${device.name ?? 'Device'} tapped 'Host / Share' and Bluetooth is ON.";
      });
      return;
    }

    setState(() {
      _progress = 0.25;
      _statusMessage = "Packaging local application data...";
    });

    final localPayload = await BluetoothSyncEngine.instance.exportSyncBundle();
    
    setState(() {
      _progress = 0.45;
      _statusMessage = "Transferring data over Bluetooth...";
    });

    await BluetoothServiceManager.instance.sendPayload(localPayload, (p) {
      setState(() {
        _progress = 0.45 + (p * 0.35);
      });
    });

    setState(() {
      _progress = 0.85;
      _statusMessage = "Receiving response and merging latest records...";
    });

    final stream = BluetoothServiceManager.instance.receivePayloadStream((p) {
      setState(() {
        _progress = 0.85 + (p * 0.15);
      });
    });

    if (stream != null) {
      stream.listen((incomingPayload) async {
        await BluetoothSyncEngine.instance.importAndMergeSyncBundle(incomingPayload);
        setState(() {
          _isSyncing = false;
          _progress = 1.0;
          _statusMessage = "✅ Both devices synced successfully!";
        });
      }, onError: (e) {
        setState(() {
          _isSyncing = false;
          _statusMessage = "Sync error: $e";
        });
      });
    } else {
      setState(() {
        _isSyncing = false;
        _progress = 1.0;
        _statusMessage = "✅ Transfer complete!";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF2DD4A8);
    const cardBgColor = Color(0xFF151520);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bluetooth, color: accentColor, size: 24.sp),
                  SizedBox(width: 10.w),
                  Text(
                    "Offline Bluetooth Sync",
                    style: AppFonts.display(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            "Synchronize your app data directly between 2 smartphones over Bluetooth. No internet or servers required.",
            style: AppFonts.text(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 20.h),
          if (!_isPermissionGranted || !_isBluetoothEnabled)
            Container(
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: Colors.amber.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      !_isBluetoothEnabled
                          ? "Bluetooth is disabled. Please turn on Bluetooth."
                          : "Bluetooth permissions required for scanning.",
                      style: AppFonts.text(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (!_isBluetoothEnabled) {
                        await BluetoothServiceManager.instance.enableBluetooth();
                      }
                      await _initBluetooth();
                    },
                    child: const Text("ENABLE"),
                  ),
                ],
              ),
            ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _role == SyncRole.host ? accentColor : Colors.white10,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  onPressed: _isSyncing ? null : _startHostMode,
                  icon: const Icon(Icons.cell_tower, color: Colors.white),
                  label: Text("Host / Share", style: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _role == SyncRole.receiver ? accentColor : Colors.white10,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
                  ),
                  onPressed: _isSyncing
                      ? null
                      : () {
                          setState(() {
                            _role = SyncRole.receiver;
                            _loadPairedDevices();
                          });
                        },
                  icon: const Icon(Icons.sync_alt, color: Colors.white),
                  label: Text("Connect & Sync", style: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (_role == SyncRole.receiver) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Paired Bluetooth Devices:",
                  style: AppFonts.text(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white70,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _loadPairedDevices,
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 14.sp, color: accentColor),
                          SizedBox(width: 4.w),
                          Text("Refresh", style: AppFonts.text(fontSize: 11, color: accentColor)),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    GestureDetector(
                      onTap: () => BluetoothServiceManager.instance.openSettings(),
                      child: Row(
                        children: [
                          Icon(Icons.settings_bluetooth, size: 14.sp, color: accentColor),
                          SizedBox(width: 4.w),
                          Text("Pair New", style: AppFonts.text(fontSize: 11, color: accentColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8.h),
            if (_pairedDevices.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Text(
                  "No paired devices found. Tap 'Pair New' to open Android Bluetooth Settings.",
                  style: AppFonts.text(fontSize: 12, color: Colors.white54),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 160.h),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _pairedDevices.length,
                  itemBuilder: (context, index) {
                    final device = _pairedDevices[index];
                    final isSelected = _selectedDevice?.address == device.address;
                    return Card(
                      color: isSelected ? accentColor.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      margin: EdgeInsets.only(bottom: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        side: BorderSide(
                          color: isSelected ? accentColor : Colors.transparent,
                        ),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.phone_android, color: accentColor),
                        title: Text(
                          device.name ?? "Unknown Device",
                          style: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: Text(
                          device.address,
                          style: AppFonts.text(fontSize: 11, color: Colors.white54),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                          ),
                          onPressed: _isSyncing ? null : () => _startReceiverMode(device),
                          child: const Text("SYNC"),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
          SizedBox(height: 16.h),
          if (_isSyncing || _progress > 0) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white10,
              color: accentColor,
              minHeight: 8.h,
              borderRadius: BorderRadius.circular(4.r),
            ),
            SizedBox(height: 12.h),
          ],
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Row(
              children: [
                Icon(
                  _isSyncing ? Icons.sync : Icons.info_outline,
                  color: accentColor,
                  size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppFonts.text(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
