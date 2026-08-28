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
  bool _isSyncing = false;
  double _progress = 0.0;
  String _statusMessage = "Tap 'SEND VIA BLUETOOTH' or 'IMPORT FILE' to sync data.";

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

          // Status & Info Banner
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
                          : Icons.info_outline_rounded),
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
