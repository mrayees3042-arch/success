import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<void> main() async {
  const size = 1024.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rect = Rect.fromLTWH(0, 0, size, size);

  final bgPaint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF9F4E8), Color(0xFFEDE5CC)],
    ).createShader(rect);
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(42), const Radius.circular(180)),
    bgPaint,
  );

  final borderPaint = Paint()
    ..color = const Color(0xFFB8963E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 8;
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(46), const Radius.circular(174)),
    borderPaint,
  );

  final arabicPainter = TextPainter(
    text: const TextSpan(
      text: '\u0645\u064f\u062a\u064e\u0651\u0642\u0650\u064a\u0646',
      style: TextStyle(
        color: Color(0xFF4A3200),
        fontFamily: 'NotoNaskhArabic',
        fontWeight: FontWeight.w700,
        fontSize: 178,
      ),
    ),
    textDirection: TextDirection.rtl,
  )..layout(maxWidth: size - 160);
  arabicPainter.paint(
    canvas,
    Offset((size - arabicPainter.width) / 2, 354),
  );

  final subtitlePainter = TextPainter(
    text: const TextSpan(
      text: 'MUTTAQIN',
      style: TextStyle(
        color: Color(0xFF7A5C1E),
        fontWeight: FontWeight.w700,
        fontSize: 72,
        letterSpacing: 8,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: size - 160);
  subtitlePainter.paint(
    canvas,
    Offset((size - subtitlePainter.width) / 2, 592),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Could not encode launcher icon.');
  }

  final file = File('assets/icon/app_icon.png');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes.buffer.asUint8List());
}
