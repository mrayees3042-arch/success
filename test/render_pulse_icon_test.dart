import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Render Muttaqin logo v5 - ultra-bold premium M', () async {
    const double S = 1024.0;
    const double C = S / 2;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, S, S));

    // ---- BG: Premium dark slate (#13161C) ----
    canvas.drawRect(Rect.fromLTWH(0, 0, S, S), Paint()..color = const Color(0xFF13161C));

    // ---- Ambient radial glow ----
    canvas.drawRect(
      Rect.fromLTWH(0, 0, S, S),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(C, C * 0.85), S * 0.42,
          [const Color(0xFF2ecc71).withOpacity(0.16), Colors.transparent],
          [0.0, 1.0],
        ),
    );

    // Safe zone bounds (66% of 108dp canvas = ~200 to ~824)
    // We make M fill ~78% of canvas, bold & powerful
    const double leftX = 220.0;
    const double rightX = 804.0;
    const double topY = 220.0;
    const double botY = 800.0;
    const double valleyY = 530.0;
    const double strokeW = 110.0; // Very bold for maximum 48dp readability!

    // Create M path with vertical outer legs and clean center V
    final pLeftFoot = Offset(leftX, botY);
    final pLeftTop = Offset(leftX, topY);
    final pValley = Offset(C, valleyY);
    final pRightTop = Offset(rightX, topY);
    final pRightFoot = Offset(rightX, botY);

    final mPath = Path()
      ..moveTo(pLeftFoot.dx, pLeftFoot.dy)
      ..lineTo(pLeftTop.dx, pLeftTop.dy)
      ..lineTo(pValley.dx, pValley.dy)
      ..lineTo(pRightTop.dx, pRightTop.dy)
      ..lineTo(pRightFoot.dx, pRightFoot.dy);

    // 1. Soft ambient shadow behind M for 3D elevation
    final shadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW + 24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF2ecc71).withOpacity(0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawPath(mPath, shadowPaint);

    // 2. Main M shape - Bold gradient stroke with rounded caps & joins
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        Offset(C, topY),
        Offset(C, botY),
        [
          const Color(0xFF38BDF8), // Vibrant cyan-blue top
          const Color(0xFF2ECC71), // Brand emerald green base
        ],
        [0.0, 1.0],
      );
    canvas.drawPath(mPath, mainPaint);

    // 3. Inner highlight line along top edge for glass/metallic texture
    final innerHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW * 0.35
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        Offset(C, topY),
        Offset(C, botY),
        [
          Colors.white.withOpacity(0.35),
          Colors.white.withOpacity(0.0),
        ],
        [0.0, 0.7],
      );
    canvas.drawPath(mPath, innerHighlight);

    // 4. Data Nodes (colored dots at key vertices for brand identity)
    final dots = <MapEntry<Offset, Color>>[
      MapEntry(pLeftTop, const Color(0xFF38BDF8)),   // Mind (Blue)
      MapEntry(pValley, const Color(0xFFF2C94C)),    // Balance (Yellow)
      MapEntry(pRightTop, const Color(0xFFA855F7)),  // Spirit (Purple)
    ];

    for (final dot in dots) {
      // Glow behind dot
      canvas.drawCircle(
        dot.key, 32,
        Paint()
          ..color = dot.value.withOpacity(0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      // Solid dot ring
      canvas.drawCircle(dot.key, 22, Paint()..color = const Color(0xFF13161C));
      canvas.drawCircle(dot.key, 18, Paint()..color = dot.value);
      // White focal point
      canvas.drawCircle(
        Offset(dot.key.dx - 4, dot.key.dy - 4), 6,
        Paint()..color = Colors.white.withOpacity(0.8),
      );
    }

    // 5. Guiding star spark above right peak (Growth summit)
    final starCenter = Offset(rightX, topY - strokeW * 0.6 - 12);
    canvas.drawCircle(
      starCenter, 14,
      Paint()
        ..color = const Color(0xFFA855F7).withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(starCenter, 5, Paint()..color = Colors.white);

    // RENDER TO PNG
    final picture = rec.endRecording();
    final image = await picture.toImage(S.toInt(), S.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('assets/icon/app_icon.png').writeAsBytes(byteData!.buffer.asUint8List());
    print('✓ Rendered Muttaqin ultra-bold logo v5');
  });
}
