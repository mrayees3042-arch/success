import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:success/core/app_fonts.dart';
import 'package:success/services/bluetooth_service.dart';
import 'package:success/services/bluetooth_sync_engine.dart';

class BlinkingGreenDot extends StatefulWidget {
  final String label;
  const BlinkingGreenDot({super.key, this.label = "Paired Link Active"});

  @override
  State<BlinkingGreenDot> createState() => _BlinkingGreenDotState();
}

class _BlinkingGreenDotState extends State<BlinkingGreenDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.25, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const greenColor = Color(0xFF00FF66);
    return AnimatedBuilder(
      animation: _opacityAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: greenColor.withOpacity(0.12 * _opacityAnimation.value),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: greenColor.withOpacity(0.6 * _opacityAnimation.value),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.r,
                height: 8.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: greenColor.withOpacity(_opacityAnimation.value),
                  boxShadow: [
                    BoxShadow(
                      color: greenColor.withOpacity(0.8 * _opacityAnimation.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                widget.label,
                style: AppFonts.compact(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: greenColor.withOpacity(_opacityAnimation.value),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

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

  @override
  void dispose() {
    BluetoothServiceManager.instance.disconnect();
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
    }
  }

  Future<void> _loadPairedDevices() async {
    final devices = await BluetoothServiceManager.instance.getPairedDevices();
    if (!mounted) return;
    setState(() {
      _pairedDevices = devices;
    });
  }

  Future<void> _startHostMode() async {
    setState(() {
      _role = SyncRole.host;
      _isSyncing = true;
      _progress = 0.1;
      _statusMessage = "📡 Host Mode Active (Discoverable). On second phone, tap SYNC.";
    });

    final success = await BluetoothServiceManager.instance.startServer(
      (Uint8List payload) async {
        if (!mounted) return;
        setState(() {
          _statusMessage = "Receiving incoming sync bundle...";
        });
        final merged = await BluetoothSyncEngine.instance.importAndMergeSyncBundle(payload);
        if (merged) {
          final replyPayload = await BluetoothSyncEngine.instance.exportSyncBundle();
          await BluetoothServiceManager.instance.sendPayload(replyPayload, (p) {
            if (mounted) setState(() => _progress = p);
          });
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _progress = 1.0;
              _statusMessage = "✅ Offline Sync Complete! All data synchronized.";
            });
          }
        }
      },
      (double p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!success && mounted) {
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
      _statusMessage = "Connecting to ${device.name ?? 'Device'}...";
    });

    try {
      final connected = await BluetoothServiceManager.instance.connectToDevice(device, maxAttempts: 2);
      if (!connected) {
        if (!mounted) return;
        setState(() {
          _isSyncing = false;
          _statusMessage = "❌ Could not connect to ${device.name ?? 'Device'}. Ensure Bluetooth is ON and Host Mode is active.";
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _progress = 0.25;
        _statusMessage = "Packaging local application data...";
      });

      final localPayload = await BluetoothSyncEngine.instance.exportSyncBundle();
      
      if (!mounted) return;
      setState(() {
        _progress = 0.45;
        _statusMessage = "Transferring data over Bluetooth...";
      });

      await BluetoothServiceManager.instance.sendPayload(localPayload, (p) {
        if (mounted) {
          setState(() {
            _progress = 0.45 + (p * 0.35);
          });
        }
      });

      if (!mounted) return;
      setState(() {
        _progress = 0.85;
        _statusMessage = "Receiving response and merging latest records...";
      });

      final stream = BluetoothServiceManager.instance.receivePayloadStream((p) {
        if (mounted) {
          setState(() {
            _progress = 0.85 + (p * 0.15);
          });
        }
      });

      if (stream != null) {
        stream.listen((incomingPayload) async {
          await BluetoothSyncEngine.instance.importAndMergeSyncBundle(incomingPayload);
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _progress = 1.0;
              _statusMessage = "✅ Both devices synced successfully!";
            });
          }
        }, onError: (e) {
          if (mounted) {
            setState(() {
              _isSyncing = false;
              _statusMessage = "Sync error: $e";
            });
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isSyncing = false;
            _progress = 1.0;
            _statusMessage = "✅ Transfer complete!";
          });
        }
      }
    } finally {
      await BluetoothServiceManager.instance.disconnect();
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
            children: [
              Icon(Icons.bluetooth_searching_rounded, color: accentColor, size: 22.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  "Offline Bluetooth Sync",
                  style: AppFonts.display(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            "Synchronize application data directly between smartphones over Bluetooth. Zero internet required.",
            style: AppFonts.text(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 14.h),

          // System Bluetooth File Share / Backup Options
          Container(
            padding: EdgeInsets.all(12.r),
            margin: EdgeInsets.only(bottom: 14.h),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.folder_zip_rounded, color: accentColor, size: 18.sp),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        "Bluetooth File Share (100% Reliable)",
                        style: AppFonts.text(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  "Packages all habits, workouts, debts, & settings into a file. Send over Bluetooth just like a photo or video!",
                  style: AppFonts.text(fontSize: 11, color: Colors.white70),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        onPressed: () async {
                          final ok = await BluetoothSyncEngine.instance.exportAndShareDataFile();
                          if (mounted) {
                            setState(() {
                              _statusMessage = ok
                                  ? "📤 Backup file generated! Select Bluetooth to send."
                                  : "Data file export ready.";
                            });
                          }
                        },
                        icon: const Icon(Icons.share, color: Colors.black, size: 14),
                        label: Text("SEND VIA BLUETOOTH",
                            style: AppFonts.compact(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.black)),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: accentColor),
                          padding: EdgeInsets.symmetric(vertical: 10.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        onPressed: () async {
                          final ok = await BluetoothSyncEngine.instance.importDataFile();
                          if (mounted) {
                            setState(() {
                              _statusMessage = ok
                                  ? "✅ Restored all application data from backup file!"
                                  : "No file imported or import cancelled.";
                            });
                          }
                        },
                        icon: const Icon(Icons.download, color: accentColor, size: 14),
                        label: Text("IMPORT FILE",
                            style: AppFonts.compact(fontSize: 9.5, fontWeight: FontWeight.bold, color: accentColor)),
                      ),
                    ),
                  ],
                ),
              ],
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

          // Two Role Selector Buttons: Host / Share | Connect & Sync
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
                  label: Text("Host / Share",
                      style: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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
                  label: Text("Connect & Sync",
                      style: AppFonts.text(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.name ?? "Unknown Device",
                              style: AppFonts.text(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                          const BlinkingGreenDot(label: "PAIRED"),
                        ],
                      ),
                      subtitle: Text(
                        device.address,
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
                          "SYNC",
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
