import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render Muttaqin logo mark v3 - unmistakable M with data dots', () async {
    const double size = 1024.0;
    const double center = size / 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // ---- Background: Dark but NOT pure black (#15181e) ----
    // Visible on OLED, doesn't become a hole on gray wallpapers
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, size, size),
      Paint()..color = const Color(0xFF15181E),
    );

    // ---- Subtle radial glow for depth ----
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(center, center * 0.85),
        size * 0.35,
        [
          const Color(0xFF2ecc71).withOpacity(0.10),
          const Color(0xFF2ecc71).withOpacity(0.03),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), glowPaint);

    // ---- THE MARK: Unmistakable bold "M" within 66% safe zone ----
    // Safe zone: 17%–83% = ~174 to ~850
    const double padX = 210.0;    // left/right margin
    const double baseY = 720.0;   // bottom baseline (inside safe zone)
    const double leftTopY = 310.0;  // left peak
    const double rightTopY = 260.0; // right peak (taller = growth)
    const double valleyY = 560.0;   // center valley
    const double strokeW = 82.0;    // BOLD stroke for 48dp visibility

    // M vertices: 5 points forming unmistakable M
    // Left foot → Left top → Center valley → Right top → Right foot
    final pLeftFoot = Offset(padX, baseY);
    final pLeftTop = Offset(padX, leftTopY);
    final pValley = Offset(center, valleyY);
    final pRightTop = Offset(size - padX, rightTopY);
    final pRightFoot = Offset(size - padX, baseY);

    final mPath = Path()
      ..moveTo(pLeftFoot.dx, pLeftFoot.dy)   // left foot (baseline)
      ..lineTo(pLeftTop.dx, pLeftTop.dy)     // left vertical UP
      ..lineTo(pValley.dx, pValley.dy)       // diagonal DOWN to valley
      ..lineTo(pRightTop.dx, pRightTop.dy)   // diagonal UP to right peak
      ..lineTo(pRightFoot.dx, pRightFoot.dy); // right vertical DOWN

    // Outer glow for depth (makes it not look like a wireframe)
    final glowStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 20
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2ecc71).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(mPath, glowStroke);

    // Main stroke: exact app green #2ecc71
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2ecc71);
    canvas.drawPath(mPath, mainPaint);

    // ---- Colored data dots from Pulse M — texture + meaning ----
    // Each dot = a life domain tracked by the app
    final dots = <MapEntry<Offset, Color>>[
      MapEntry(pLeftFoot, const Color(0xFF2ecc71)),   // green: health
      MapEntry(pLeftTop, const Color(0xFF38bdf8)),    // blue: mind
      MapEntry(pValley, const Color(0xFFF2C94C)),     // yellow: balance
      MapEntry(pRightTop, const Color(0xFFA855F7)),   // purple: spirit
      MapEntry(pRightFoot, const Color(0xFF2ecc71)),  // green: growth
    ];

    for (final dot in dots) {
      // Outer glow
      canvas.drawCircle(
        dot.key,
        24,
        Paint()
          ..color = dot.value.withOpacity(0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      // Solid dot
      canvas.drawCircle(dot.key, 18, Paint()..color = dot.value);
      // Inner highlight
      canvas.drawCircle(
        Offset(dot.key.dx - 4, dot.key.dy - 4),
        6,
        Paint()..color = Colors.white.withOpacity(0.5),
      );
    }

    // ---- Guiding star at highest peak (right top) ----
    canvas.drawCircle(
      Offset(pRightTop.dx, pRightTop.dy - strokeW / 2 - 16),
      8,
      Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      Offset(pRightTop.dx, pRightTop.dy - strokeW / 2 - 16),
      3,
      Paint()..color = Colors.white,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File('assets/icon/app_icon.png');
    await file.writeAsBytes(buffer);
    print('✓ Rendered Muttaqin logo mark v3');
  });
}
