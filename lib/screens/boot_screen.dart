import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:success/main.dart';
import 'package:success/providers/theme_provider.dart';
import 'package:success/services/audio_service.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _shineController;
  late AnimationController _sequenceController;

  // Animations driven by sequence controller
  late Animation<double> _starScale;
  late Animation<double> _starRotate;
  late Animation<double> _arabicFadeUp;
  late Animation<double> _arabicSlideUp;
  late Animation<double> _englishFadeUp;
  late Animation<double> _englishSlideUp;
  late Animation<double> _builtForFadeUp;
  late Animation<double> _builtForSlideUp;
  late Animation<double> _taglineFadeUp;
  late Animation<double> _taglineSlideUp;
  late Animation<double> _progressBarFade;
  late Animation<double> _progressBarFill;

  @override
  void initState() {
    super.initState();

    // 1. App Launch sound
    AudioService.playLaunch();

    // 2. Infinite rotation for the star (20s per revolution)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // 3. Infinite shine sweep (3s ease-in-out alternate)
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // 4. Main 8-second sequence controller
    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    // Star Fly-in: from 0.2s to 1.0s (duration 0.8s)
    // Custom cubic-bezier(.23,1,.32,1) curve matches Curves.easeOutQuart closely
    const starCurve = Cubic(0.23, 1.0, 0.32, 1.0);
    _starScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.2 / 8.0, 1.0 / 8.0, curve: starCurve),
      ),
    );
    _starRotate = Tween<double>(begin: -math.pi / 2, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.2 / 8.0, 1.0 / 8.0, curve: starCurve),
      ),
    );

    // Fade-up timings
    // Arabic "مُتَّقِين" fade-up: 1.6s
    _arabicFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.6 / 8.0, curve: Curves.easeOut),
      ),
    );
    _arabicSlideUp = Tween<double>(begin: 15.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.6 / 8.0, curve: Curves.easeOut),
      ),
    );

    // "MUTTAQIN" fade-up: 1.8s
    _englishFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.8 / 8.0, curve: Curves.easeOut),
      ),
    );
    _englishSlideUp = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 1.8 / 8.0, curve: Curves.easeOut),
      ),
    );

    // "Built for" + "RAYEES" fade-up: 2.2s
    _builtForFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.2 / 8.0, curve: Curves.easeOut),
      ),
    );
    _builtForSlideUp = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.2 / 8.0, curve: Curves.easeOut),
      ),
    );

    // Tagline fade-up: 2.8s
    _taglineFadeUp = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.8 / 8.0, curve: Curves.easeOut),
      ),
    );
    _taglineSlideUp = Tween<double>(begin: 10.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 2.8 / 8.0, curve: Curves.easeOut),
      ),
    );

    // Progress bar fade-in: 3.0s
    _progressBarFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 3.0 / 8.0, curve: Curves.easeIn),
      ),
    );

    // Progress bar fill: 0 -> 100% over 4.8s starting at 3.2s (ends at 8.0s)
    _progressBarFill = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(3.2 / 8.0, 8.0 / 8.0, curve: Curves.easeInOut),
      ),
    );

    // Start sequence
    _sequenceController.forward().then((_) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 800),
            pageBuilder: (context, animation, secondaryAnimation) => const MainScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _shineController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final isDark = themeNotifier.isDark;
    
    // Background color: #06060F dark or #F5F0E8 in light mode
    final bgColor = isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8);
    final goldColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFB8860B);
    final text3Color = isDark ? const Color(0x8CFFFFFF) : const Color(0x80000000);
    final text4Color = isDark ? const Color(0x4DFFFFFF) : const Color(0x4D000000);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Star with Fly-in and Rotation animations
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _sequenceController,
                      _rotationController,
                      _shineController,
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _starScale.value,
                        child: Transform.rotate(
                          angle: _starRotate.value + (_rotationController.value * 2 * math.pi),
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: CustomPaint(
                              painter: StarPainter(
                                isDark: isDark,
                                shineProgress: _shineController.value,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Sparkles overlay around the star
                  SizedBox(
                    width: 240,
                    height: 160,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Staggered sparkles (delays: 2.0s, 2.4s, 2.8s, 3.2s)
                        SparkleWidget(angle: -math.pi / 4, delay: const Duration(milliseconds: 2000)),
                        SparkleWidget(angle: math.pi / 4, delay: const Duration(milliseconds: 2400)),
                        SparkleWidget(angle: 3 * math.pi / 4, delay: const Duration(milliseconds: 2800)),
                        SparkleWidget(angle: -3 * math.pi / 4, delay: const Duration(milliseconds: 3200)),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),

                  // Arabic Text: "مُتَّقِين"
                  AnimatedBuilder(
                    animation: _sequenceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _arabicFadeUp.value,
                        child: Transform.translate(
                          offset: Offset(0, _arabicSlideUp.value),
                          child: Text(
                            "مُتَّقِين",
                            style: GoogleFonts.amiri(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: goldColor,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // English Text: "MUTTAQIN"
                  AnimatedBuilder(
                    animation: _sequenceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _englishFadeUp.value,
                        child: Transform.translate(
                          offset: Offset(0, _englishSlideUp.value),
                          child: Text(
                            "MUTTAQIN",
                            style: GoogleFonts.syne(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: goldColor.withValues(alpha: 0.35),
                              letterSpacing: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Built For & RAYEES
                  AnimatedBuilder(
                    animation: _sequenceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _builtForFadeUp.value,
                        child: Transform.translate(
                          offset: Offset(0, _builtForSlideUp.value),
                          child: Column(
                            children: [
                              Text(
                                "BUILT FOR",
                                style: GoogleFonts.dmSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                  color: text3Color,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "RAYEES",
                                style: GoogleFonts.syne(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: text3Color,
                                  letterSpacing: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 36),

                  // Progress Bar
                  AnimatedBuilder(
                    animation: _sequenceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _progressBarFade.value,
                        child: Container(
                          width: 90,
                          height: 2,
                          decoration: BoxDecoration(
                            color: isDark 
                                ? Colors.white.withValues(alpha: 0.06) 
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: _progressBarFill.value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    goldColor,
                                    isDark ? const Color(0xFF00C896) : const Color(0xFF0A7A5A),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Tagline at bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _sequenceController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _taglineFadeUp.value,
                    child: Transform.translate(
                      offset: Offset(0, _taglineSlideUp.value),
                      child: Text(
                        "“Indeed, with hardship comes ease.”",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: text4Color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 8-Point Star Painter
class StarPainter extends CustomPainter {
  StarPainter({required this.isDark, required this.shineProgress});

  final bool isDark;
  final double shineProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2; // Outer radius (80px)
    final innerR = outerR * 0.42;       // Inner radius (valley depth)
    final outerRInner = outerR * 0.6;   // Inner star outer radius
    final innerRInner = outerRInner * 0.42;

    // Define main linear gradient for stainless steel
    final Paint outerLightPaint = Paint();
    final Paint outerDarkPaint = Paint();
    
    final Paint innerLightPaint = Paint();
    final Paint innerDarkPaint = Paint();

    // Dark / Light palettes for the steel gradient
    if (isDark) {
      outerLightPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFF5E5E6E), const Color(0xFF454552)],
      );
      outerDarkPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFF1E1E28), const Color(0xFF16161D)],
      );
      
      innerLightPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFFE8B84B), const Color(0xFFB8860B)], // Inner star has gold tint
      );
      innerDarkPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFFB8860B), const Color(0xFF8A6D0A)],
      );
    } else {
      // Day palette
      outerLightPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFFEFEFFA), const Color(0xFFD3D3D8)],
      );
      outerDarkPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFFB8B8C8), const Color(0xFF9E9EAE)],
      );
      
      innerLightPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFFB8860B), const Color(0xFFE8B84B)],
      );
      innerDarkPaint.shader = ui.Gradient.linear(
        Offset(-outerR, -outerR),
        Offset(outerR, outerR),
        [const Color(0xFF8A6D0A), const Color(0xFF5A4905)],
      );
    }

    // Save layer to apply shine clipping
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Draw Outer Star
    for (int k = 0; k < 8; k++) {
      final double theta = k * math.pi / 4;
      final double phiPrev = theta - math.pi / 8;
      final double phiNext = theta + math.pi / 8;

      final offsetOuter = Offset(center.dx + outerR * math.cos(theta), center.dy + outerR * math.sin(theta));
      final offsetPrev = Offset(center.dx + innerR * math.cos(phiPrev), center.dy + innerR * math.sin(phiPrev));
      final offsetNext = Offset(center.dx + innerR * math.cos(phiNext), center.dy + innerR * math.sin(phiNext));

      // Left half (light side)
      final pathLeft = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(offsetOuter.dx, offsetOuter.dy)
        ..lineTo(offsetNext.dx, offsetNext.dy)
        ..close();
      canvas.drawPath(pathLeft, outerLightPaint);

      // Right half (dark side)
      final pathRight = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(offsetOuter.dx, offsetOuter.dy)
        ..lineTo(offsetPrev.dx, offsetPrev.dy)
        ..close();
      canvas.drawPath(pathRight, outerDarkPaint);
    }

    // 2. Draw Inner Star
    for (int k = 0; k < 8; k++) {
      final double theta = k * math.pi / 4 + math.pi / 8; // rotated for offset layering
      final double phiPrev = theta - math.pi / 8;
      final double phiNext = theta + math.pi / 8;

      final offsetOuter = Offset(center.dx + outerRInner * math.cos(theta), center.dy + outerRInner * math.sin(theta));
      final offsetPrev = Offset(center.dx + innerRInner * math.cos(phiPrev), center.dy + innerRInner * math.sin(phiPrev));
      final offsetNext = Offset(center.dx + innerRInner * math.cos(phiNext), center.dy + innerRInner * math.sin(phiNext));

      final pathLeft = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(offsetOuter.dx, offsetOuter.dy)
        ..lineTo(offsetNext.dx, offsetNext.dy)
        ..close();
      canvas.drawPath(pathLeft, innerLightPaint);

      final pathRight = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(offsetOuter.dx, offsetOuter.dy)
        ..lineTo(offsetPrev.dx, offsetPrev.dy)
        ..close();
      canvas.drawPath(pathRight, innerDarkPaint);
    }

    // 3. Draw Center Hub
    final hubPaint = Paint();
    final goldColor = isDark ? const Color(0xFFE8B84B) : const Color(0xFFB8860B);
    final goldDark = isDark ? const Color(0xFF8A6D0A) : const Color(0xFF5A4905);
    
    hubPaint.shader = ui.Gradient.radial(
      center,
      15.0,
      [goldColor, goldDark],
    );
    canvas.drawCircle(center, 15.0, hubPaint);
    canvas.drawCircle(center, 4.0, Paint()..color = isDark ? const Color(0xFF06060F) : const Color(0xFFF5F0E8));

    // 4. Gloss Shine Overlay: Animated diagonal band using BlendMode.srcIn
    final double sweepOffset = -100.0 + (shineProgress * 200.0);
    final shinePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(center.dx + sweepOffset - 40, center.dy + sweepOffset - 40),
        Offset(center.dx + sweepOffset + 40, center.dy + sweepOffset + 40),
        [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.4),
          Colors.white.withValues(alpha: 0.0),
        ],
        [0.0, 0.5, 1.0],
      )
      ..blendMode = BlendMode.srcIn; // Only draw inside the star's shape

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), shinePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.shineProgress != shineProgress;
  }
}

// Sparkle Widget (translates outward + scales 0 -> 1 -> 0)
class SparkleWidget extends StatefulWidget {
  const SparkleWidget({super.key, required this.angle, required this.delay});

  final double angle;
  final Duration delay;

  @override
  State<SparkleWidget> createState() => _SparkleWidgetState();
}

class _SparkleWidgetState extends State<SparkleWidget> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(widget.delay, () {
      if (mounted) {
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
        )..repeat();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final progress = _controller!.value;
        // Translate from r=45 (inner radius area) to r=115 (outer area)
        final distance = 45.0 + (115.0 - 45.0) * progress;
        final x = distance * math.cos(widget.angle);
        final y = distance * math.sin(widget.angle);
        final scale = math.sin(progress * math.pi); // 0 -> 1 -> 0

        return Positioned(
          left: 120 + x - 1.5, // 120 is center of width (240 / 2)
          top: 80 + y - 1.5,   // 80 is center of height (160 / 2)
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.white, blurRadius: 2, spreadRadius: 1),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
