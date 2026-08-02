import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render Muttaqin logo mark - bold geometric M mountain', () async {
    const double size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // ---- Background: App's dark theme ----
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFF0D1117),
    );

    // ---- Subtle radial glow behind the mark ----
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(size / 2, size * 0.45),
        size * 0.4,
        [
          const Color(0xFF2ecc71).withOpacity(0.15),
          const Color(0xFF2ecc71).withOpacity(0.05),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), glowPaint);

    // ---- THE MARK: Bold geometric "M" as twin mountain peaks ----
    // Design: Two ascending peaks forming the letter M
    // Left peak shorter, right peak taller = growth trajectory
    // Flat bottom anchors it

    const double padX = 180; // horizontal padding
    const double baseY = 720; // bottom of the M
    const double leftPeakY = 340; // left peak height
    const double rightPeakY = 220; // right peak height (taller = growth)
    const double valleyY = 560; // center valley
    const double strokeW = 72; // bold stroke

    // The M path: left foot → left peak → valley → right peak → right foot
    final mPath = Path()
      ..moveTo(padX, baseY)
      ..lineTo(padX, leftPeakY)
      ..lineTo(size / 2, valleyY)
      ..lineTo(size - padX, rightPeakY)
      ..lineTo(size - padX, baseY);

    // Green gradient stroke matching app theme
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        Offset(padX, rightPeakY),
        Offset(size - padX, baseY),
        [
          const Color(0xFF38bdf8), // sky blue at top
          const Color(0xFF2ecc71), // green at bottom
        ],
      );

    canvas.drawPath(mPath, gradientPaint);

    // ---- Subtle accent: small upward arrow tip on the right peak ----
    // Reinforces "growth" without adding clutter
    final arrowSize = 28.0;
    final arrowTipX = size - padX;
    final arrowTipY = rightPeakY - strokeW / 2 - 8;

    // Small luminous dot at the peak (like a guiding star)
    final starPaint = Paint()
      ..color = const Color(0xFF38bdf8)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(arrowTipX, arrowTipY), 14, starPaint);
    canvas.drawCircle(
      Offset(arrowTipX, arrowTipY),
      6,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File('assets/icon/app_icon.png');
    await file.writeAsBytes(buffer);
    print('✓ Rendered Muttaqin logo mark to assets/icon/app_icon.png');
  });
}
