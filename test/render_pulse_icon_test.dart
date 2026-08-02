import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render exact Pulse M SVG launcher icon', () async {
    const double size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    const scale = size / 100.0;

    // Background: Dark Obsidian #0A0C10
    final bgPaint = Paint()..color = const Color(0xFF0A0C10);
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), bgPaint);

    // Baseline: Line x1=12, y1=78, x2=88, y2=78, stroke=#23262d, width=2
    final baseLinePaint = Paint()
      ..color = const Color(0xFF23262D)
      ..strokeWidth = 2.5 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      const Offset(12 * scale, 78 * scale),
      const Offset(88 * scale, 78 * scale),
      baseLinePaint,
    );

    // LinearGradient: x1=0, y1=100 -> x2=100, y2=0
    // Stops: 0 -> #2ecc71, 0.5 -> #38bdf8, 1.0 -> #a855f7
    final gradShader = ui.Gradient.linear(
      const Offset(0 * scale, 100 * scale),
      const Offset(100 * scale, 0 * scale),
      [
        const Color(0xFF2ECC71),
        const Color(0xFF38BDF8),
        const Color(0xFFA855F7),
      ],
      [0.0, 0.5, 1.0],
    );

    // Glow effect behind path
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = gradShader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Path: M18 78 L18 55 L35 35 L50 50 L65 20 L82 40 L82 78
    final path = Path()
      ..moveTo(18 * scale, 78 * scale)
      ..lineTo(18 * scale, 55 * scale)
      ..lineTo(35 * scale, 35 * scale)
      ..lineTo(50 * scale, 50 * scale)
      ..lineTo(65 * scale, 20 * scale)
      ..lineTo(82 * scale, 40 * scale)
      ..lineTo(82 * scale, 78 * scale);

    canvas.drawPath(path, glowPaint);

    // Main Stroke: width 5, round cap, round join
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = gradShader;

    canvas.drawPath(path, mainPaint);

    // Circles (Nodes):
    // cx=18, cy=55, r=4, #2ecc71
    // cx=35, cy=35, r=4, #38bdf8
    // cx=50, cy=50, r=4, #f2c94c
    // cx=65, cy=20, r=4, #a855f7
    // cx=82, cy=40, r=4, #ef4444

    final nodes = [
      {'cx': 18.0, 'cy': 55.0, 'r': 4.5, 'color': const Color(0xFF2ECC71)},
      {'cx': 35.0, 'cy': 35.0, 'r': 4.5, 'color': const Color(0xFF38BDF8)},
      {'cx': 50.0, 'cy': 50.0, 'r': 4.5, 'color': const Color(0xFFF2C94C)},
      {'cx': 65.0, 'cy': 20.0, 'r': 4.5, 'color': const Color(0xFFA855F7)},
      {'cx': 82.0, 'cy': 40.0, 'r': 4.5, 'color': const Color(0xFFEF4444)},
    ];

    for (final node in nodes) {
      final center = Offset(
        (node['cx'] as double) * scale,
        (node['cy'] as double) * scale,
      );
      final radius = (node['r'] as double) * scale;
      final color = node['color'] as Color;

      // Glow behind node
      canvas.drawCircle(
        center,
        radius + 3 * scale,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Node circle
      canvas.drawCircle(center, radius, Paint()..color = color);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    final file = File('assets/icon/app_icon.png');
    await file.writeAsBytes(buffer);
    print('Rendered exact Pulse M SVG launcher icon to assets/icon/app_icon.png!');
  });
}
