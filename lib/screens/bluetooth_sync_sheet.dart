import 'dart:async';
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

enum SyncRole { auto, host, receiver }

class _BluetoothSyncSheetState extends State<BluetoothSyncSheet> {
  SyncRole _role = SyncRole.auto;
  bool _isPermissionGranted = false;
  bool _isBluetoothEnabled = false;
  List<BluetoothDevice> _pairedDevices = [];
  BluetoothDevice? _selectedDevice;
  bool _isSyncing = false;
  double _progress = 0.0;
  String _statusMessage = "⚡ Auto-Sync Active: Scanning for paired devices...";
  Timer? _autoSyncTimer;
  DateTime? _lastAutoSyncTime;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> _initBluetooth() async {
    final granted = await BluetoothServiceManager.instance.requestPermissions();
    final enabled = await BluetoothServiceManager.instance.isBluetoothEnabled();

    if (!mounted) return;
    setState(() {
      _isPermissionGranted = granted;
      _isBluetoothEnabled = enabled;
    });

    if (granted && enabled) {
      await _loadPairedDevices();
      _startAutoSyncLoop();
    }
  }

  Future<void> _loadPairedDevices() async {
    final devices = await BluetoothServiceManager.instance.getPairedDevices();
    if (!mounted) return;
    setState(() {
      _pairedDevices = devices;
    });
  }

  void _startAutoSyncLoop() {
    _autoSyncTimer?.cancel();
    BluetoothServiceManager.instance.makeDiscoverable(300);

    // Initial check right away
    _runAutoSyncCheck();

    // Periodic check every 5 seconds
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_role == SyncRole.auto && !_isSyncing && _isBluetoothEnabled) {
        _runAutoSyncCheck();
      }
    });
  }

  Future<void> _runAutoSyncCheck() async {
    if (_pairedDevices.isEmpty) {
      await _loadPairedDevices();
    }

    if (_pairedDevices.isEmpty || _isSyncing) return;

    // Cooldown check (don't auto-sync if we auto-synced within last 12 seconds)
    if (_lastAutoSyncTime != null &&
        DateTime.now().difference(_lastAutoSyncTime!).inSeconds < 12) {
      return;
    }

    for (var device in _pairedDevices) {
      if (_role != SyncRole.auto || !mounted) break;

      setState(() {
        _isSyncing = true;
        _selectedDevice = device;
        _progress = 0.1;
        _statusMessage = "⚡ Auto-Syncing with ${device.name ?? 'Device'}...";
      });

      final success = await BluetoothServiceManager.instance.performTwoWayAutoSync(
        device,
        (msg, prog) {
          if (mounted) {
            setState(() {
              _statusMessage = msg;
              _progress = prog;
            });
          }
        },
      );

      if (success) {
        _lastAutoSyncTime = DateTime.now();
        final formattedTime =
            "${_lastAutoSyncTime!.hour % 12 == 0 ? 12 : _lastAutoSyncTime!.hour % 12}:${_lastAutoSyncTime!.minute.toString().padLeft(2, '0')} ${_lastAutoSyncTime!.hour >= 12 ? 'PM' : 'AM'}";
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _progress = 1.0;
            _statusMessage =
                "✅ Auto-Synced with ${device.name ?? 'Device'} at $formattedTime! (100% Data Parity)";
          });
        }
        break;
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _progress = 0.0;
            _statusMessage =
                "⚡ Auto-Sync Listening: Searching for ${device.name ?? 'paired device'} in range...";
          });
        }
      }
    }
  }

  Future<void> _startHostMode() async {
    _autoSyncTimer?.cancel();
    setState(() {
      _role = SyncRole.host;
      _isSyncing = true;
      _progress = 0.1;
      _statusMessage = "📡 Host Mode Active (Discoverable). On second phone, tap SYNC.";
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
    _autoSyncTimer?.cancel();
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
        _statusMessage = "❌ Could not connect to ${device.name ?? 'Device'}. Ensure ${device.name ?? 'Device'} Bluetooth is ON.";
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
                  Icon(Icons.bluetooth_searching_rounded, color: accentColor, size: 24.sp),
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
          SizedBox(height: 6.h),
          Text(
            "Auto-syncs application data directly between smartphones over Bluetooth. Zero internet required.",
            style: AppFonts.text(
              fontSize: 12.5,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 16.h),
          if (!_isPermissionGranted || !_isBluetoothEnabled)
            Container(
              padding: EdgeInsets.all(14.r),
              margin: EdgeInsets.only(bottom: 12.h),
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

          // Three Role Selector Buttons: Auto Sync (Default) | Host | Connect
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _role == SyncRole.auto ? accentColor : Colors.white10,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: () {
                    setState(() {
                      _role = SyncRole.auto;
                      _statusMessage = "⚡ Auto-Sync Active: Scanning for paired devices...";
                    });
                    _startAutoSyncLoop();
                  },
                  icon: Icon(Icons.bolt_rounded,
                      color: _role == SyncRole.auto ? Colors.black : Colors.white, size: 16.sp),
                  label: Text("⚡ Auto Sync",
                      style: AppFonts.text(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _role == SyncRole.auto ? Colors.black : Colors.white)),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _role == SyncRole.host ? accentColor : Colors.white10,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: _isSyncing ? null : _startHostMode,
                  icon: const Icon(Icons.cell_tower, color: Colors.white, size: 16),
                  label: Text("Host",
                      style: AppFonts.text(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _role == SyncRole.receiver ? accentColor : Colors.white10,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                  ),
                  onPressed: _isSyncing
                      ? null
                      : () {
                          _autoSyncTimer?.cancel();
                          setState(() {
                            _role = SyncRole.receiver;
                            _loadPairedDevices();
                          });
                        },
                  icon: const Icon(Icons.sync_alt, color: Colors.white, size: 16),
                  label: Text("Connect",
                      style: AppFonts.text(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Paired Devices List Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Paired Bluetooth Devices (${_pairedDevices.length}):",
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
                "No paired devices found. Tap 'Pair New' to pair both phones in Android Settings.",
                style: AppFonts.text(fontSize: 12, color: Colors.white54),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 140.h),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _pairedDevices.length,
                itemBuilder: (context, index) {
                  final device = _pairedDevices[index];
                  final isSelected =
                      _selectedDevice?.address == device.address;
                  return Card(
                    color: isSelected
                        ? accentColor.withOpacity(0.2)
                        : Colors.white.withOpacity(0.05),
                    margin: EdgeInsets.only(bottom: 8.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      side: BorderSide(
                        color: isSelected ? accentColor : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.phone_android,
                          color: accentColor),
                      title: Text(
                        device.name ?? "Unknown Device",
                        style: AppFonts.text(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      subtitle: Text(
                        _role == SyncRole.auto
                            ? "Auto-Sync Enabled · Proximity Scan"
                            : device.address,
                        style: AppFonts.text(
                            fontSize: 10.5, color: Colors.white54),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: EdgeInsets.symmetric(
                              horizontal: 12.w, vertical: 4.h),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r)),
                        ),
                        onPressed: _isSyncing
                            ? null
                            : () => _startReceiverMode(device),
                        child: Text(
                          _role == SyncRole.auto ? "SYNC NOW" : "SYNC",
                          style: AppFonts.compact(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: 14.h),
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

          // Status & Auto-Sync Banner
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: _statusMessage.contains("✅")
                  ? accentColor.withOpacity(0.15)
                  : Colors.black26,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: _statusMessage.contains("✅")
                    ? accentColor.withOpacity(0.4)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isSyncing
                      ? Icons.sync_rounded
                      : (_statusMessage.contains("✅")
                          ? Icons.check_circle_rounded
                          : Icons.bolt_rounded),
                  color: accentColor,
                  size: 20.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: AppFonts.text(
                      fontSize: 12,
                      fontWeight: _statusMessage.contains("✅")
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
}
