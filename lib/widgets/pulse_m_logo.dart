import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class AnimatedPulseMLogoWidget extends StatefulWidget {
  const AnimatedPulseMLogoWidget({
    super.key,
    this.size = 44,
    this.isDark = true,
  });

  final double size;
  final bool isDark;

  @override
  State<AnimatedPulseMLogoWidget> createState() =>
      _AnimatedPulseMLogoWidgetState();
}

class _AnimatedPulseMLogoWidgetState extends State<AnimatedPulseMLogoWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      padding: EdgeInsets.all(widget.size * 0.1),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF0F121C)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(widget.size * 0.28),
        border: Border.all(
          color: const Color(0xFF00C896).withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00C896).withValues(alpha: 0.18),
            blurRadius: widget.size * 0.3,
            spreadRadius: -2,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: PulseMLogoPainter(
              pulse: _controller.value,
              isDark: widget.isDark,
            ),
          );
        },
      ),
    );
  }
}

class PulseMLogoPainter extends CustomPainter {
  PulseMLogoPainter({
    required this.pulse,
    required this.isDark,
  });

  final double pulse;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Define 5 key vertices matching Pulse M growth chart geometry
    final p0 = Offset(w * 0.10, h * 0.85); // Start bottom-left
    final p1 = Offset(w * 0.32, h * 0.30); // Top-left peak
    final p2 = Offset(w * 0.50, h * 0.65); // Valley dip
    final p3 = Offset(w * 0.68, h * 0.15); // Highest surge peak
    final p4 = Offset(w * 0.90, h * 0.85); // End bottom-right

    final points = [p0, p1, p2, p3, p4];

    const colorTeal = Color(0xFF00C896);
    const colorGold = Color(0xFFE8B84B);
    const colorPurple = Color(0xFFEC4899);
    const colorBlue = Color(0xFF3B82F6);

    // 1. Draw glowing ambient line shadow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.15);

    final linePath = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy);

    glowPaint.shader = ui.Gradient.linear(
      p0,
      p4,
      [
        colorTeal.withValues(alpha: 0.4),
        colorGold.withValues(alpha: 0.4),
        colorPurple.withValues(alpha: 0.4),
        colorBlue.withValues(alpha: 0.4),
      ],
      [0.0, 0.35, 0.70, 1.0],
    );
    canvas.drawPath(linePath, glowPaint);

    // 2. Draw Main Solid Gradient Stroke
    final mainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        p0,
        p4,
        [colorTeal, colorGold, colorPurple, colorBlue],
        [0.0, 0.35, 0.70, 1.0],
      );

    canvas.drawPath(linePath, mainPaint);

    // 3. Draw Vertex Nodes (Glowing Dots)
    final nodeColors = [colorTeal, colorTeal, colorGold, colorPurple, colorBlue];
    final nodeSizes = [w * 0.04, w * 0.06, w * 0.05, w * 0.08, w * 0.05];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final col = nodeColors[i];
      final r = nodeSizes[i];

      // Outer node glow
      canvas.drawCircle(
        p,
        r + w * 0.04,
        Paint()
          ..color = col.withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
      );

      // Inner node dot
      canvas.drawCircle(p, r, Paint()..color = Colors.white);
      canvas.drawCircle(p, r * 0.6, Paint()..color = col);
    }

    // 4. Draw Animated Pulsing Aura Ring around Highest Peak (p3)
    final pulseScale = 1.0 + (pulse * 0.7);
    final pulseOpacity = (1.0 - pulse) * 0.6;
    canvas.drawCircle(
      p3,
      w * 0.14 * pulseScale,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03
        ..color = colorPurple.withValues(alpha: pulseOpacity),
    );

    // 5. Draw Energy Wave Dot traveling along the M path
    final metrics = linePath.computeMetrics();
    if (metrics.isNotEmpty) {
      final pm = metrics.first;
      final totalLen = pm.length;
      final currentDist = (pulse * totalLen) % totalLen;
      final tangent = pm.getTangentForOffset(currentDist);

      if (tangent != null) {
        final wavePos = tangent.position;
        canvas.drawCircle(
          wavePos,
          w * 0.08,
          Paint()
            ..color = Colors.white
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
        );
        canvas.drawCircle(
          wavePos,
          w * 0.04,
          Paint()..color = Colors.white,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant PulseMLogoPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.isDark != isDark;
  }
}
